import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_exception.dart';
import '../core/api_client.dart';
import '../models/realtime_event.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(ref.read(dioProvider));
});

final realtimeConnectionStatusProvider =
    StateProvider<RealtimeStatus>((_) => RealtimeStatus.disconnected);

final realtimeEventsProvider = StreamProvider.autoDispose<RealtimeEvent>((ref) {
  final service = ref.read(realtimeServiceProvider);
  final cancelToken = CancelToken();
  final status = ref.read(realtimeConnectionStatusProvider.notifier);
  ref.onDispose(() {
    status.state = RealtimeStatus.disconnected;
    cancelToken.cancel();
  });

  return service.watchEvents(
    cancelToken: cancelToken,
    onStatus: (value) => status.state = value,
  );
});

class RealtimeService {
  RealtimeService(this._dio);
  final Dio _dio;

  Stream<RealtimeEvent> watchEvents({
    required CancelToken cancelToken,
    void Function(RealtimeStatus status)? onStatus,
    Duration initialReconnectDelay = const Duration(seconds: 1),
    Duration maxReconnectDelay = const Duration(seconds: 30),
  }) async* {
    String? lastEventId;
    var reconnectDelay = initialReconnectDelay;

    while (!cancelToken.isCancelled) {
      try {
        onStatus?.call(RealtimeStatus.connecting);
        final response = await _dio.get<ResponseBody>(
          '/realtime',
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            receiveTimeout: Duration.zero,
            headers: {
              'Accept': 'text/event-stream',
              if (lastEventId != null) 'Last-Event-ID': lastEventId,
            },
          ),
        );
        final body = response.data;
        if (body == null) {
          throw StateError('Realtime response stream is empty');
        }

        onStatus?.call(RealtimeStatus.connected);
        reconnectDelay = initialReconnectDelay;
        final decoder = SseDecoder();
        final textStream = utf8.decoder.bind(body.stream.cast<List<int>>());
        await for (final chunk in textStream) {
          for (final event in decoder.add(chunk)) {
            lastEventId = event.id;
            if (event.type == 'replay.reset') {
              onStatus?.call(RealtimeStatus.degraded);
            }
            yield event;
          }
        }
      } on DioException catch (err) {
        if (cancelToken.isCancelled || err.type == DioExceptionType.cancel) {
          break;
        }
        if (err.error is AuthException || err.response?.statusCode == 401) {
          onStatus?.call(RealtimeStatus.disconnected);
          break;
        }
        onStatus?.call(RealtimeStatus.disconnected);
      } catch (_) {
        if (cancelToken.isCancelled) break;
        onStatus?.call(RealtimeStatus.disconnected);
      }

      if (cancelToken.isCancelled) break;
      await Future.any<void>([
        Future.delayed(reconnectDelay),
        cancelToken.whenCancel.then((_) {}),
      ]);
      if (cancelToken.isCancelled) break;
      final doubledMs = reconnectDelay.inMilliseconds * 2;
      reconnectDelay = Duration(
        milliseconds: doubledMs > maxReconnectDelay.inMilliseconds
            ? maxReconnectDelay.inMilliseconds
            : doubledMs,
      );
    }
  }
}

class SseDecoder {
  String _buffer = '';
  String? _id;
  String? _event;
  final List<String> _dataLines = [];

  List<RealtimeEvent> add(String chunk) {
    _buffer += chunk;
    final events = <RealtimeEvent>[];

    for (;;) {
      final newlineIndex = _buffer.indexOf('\n');
      if (newlineIndex < 0) break;

      var line = _buffer.substring(0, newlineIndex);
      _buffer = _buffer.substring(newlineIndex + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }

      final event = _processLine(line);
      if (event != null) events.add(event);
    }

    return events;
  }

  RealtimeEvent? _processLine(String line) {
    if (line.isEmpty) return _dispatch();
    if (line.startsWith(':')) return null;

    final colonIndex = line.indexOf(':');
    final field = colonIndex < 0 ? line : line.substring(0, colonIndex);
    var value = colonIndex < 0 ? '' : line.substring(colonIndex + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'id':
        _id = value;
        break;
      case 'event':
        _event = value;
        break;
      case 'data':
        _dataLines.add(value);
        break;
    }
    return null;
  }

  RealtimeEvent? _dispatch() {
    if (_dataLines.isEmpty) {
      _id = null;
      _event = null;
      return null;
    }

    try {
      final data = jsonDecode(_dataLines.join('\n')) as Map<String, dynamic>;
      if (_id != null && _id!.isNotEmpty) data['id'] = _id;
      if (_event != null && _event!.isNotEmpty) data['type'] = _event;
      return RealtimeEvent.fromJson(data);
    } on Object {
      return null;
    } finally {
      _id = null;
      _event = null;
      _dataLines.clear();
    }
  }
}
