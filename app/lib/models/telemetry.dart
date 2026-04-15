import 'package:freezed_annotation/freezed_annotation.dart';

part 'telemetry.freezed.dart';
part 'telemetry.g.dart';

@freezed
class TelemetryPoint with _$TelemetryPoint {
  const factory TelemetryPoint({
    required DateTime ts,
    required double temperature,
    required double humidity,
  }) = _TelemetryPoint;

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) =>
      _$TelemetryPointFromJson(json);
}
