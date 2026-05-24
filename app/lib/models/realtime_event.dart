enum RealtimeStatus {
  disconnected,
  connecting,
  connected,
  degraded,
}

class RealtimeEvent {
  const RealtimeEvent({
    required this.id,
    required this.type,
    required this.deviceId,
    required this.occurredAt,
    required this.payload,
  });

  final String id;
  final String type;
  final String deviceId;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final occurredAtRaw = json['occurred_at'];
    final occurredAt = occurredAtRaw is String
        ? DateTime.tryParse(occurredAtRaw)?.toLocal()
        : null;

    return RealtimeEvent(
      id: json['id'].toString(),
      type: json['type'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      occurredAt: occurredAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }
}
