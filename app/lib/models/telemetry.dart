import 'package:freezed_annotation/freezed_annotation.dart';

part 'telemetry.freezed.dart';
part 'telemetry.g.dart';

@freezed
class TelemetryPoint with _$TelemetryPoint {
  const factory TelemetryPoint({
    required DateTime ts,
    double? temperature,
    double? humidity,
    @JsonKey(name: 'co_ppm') double? coPpm,
    @JsonKey(name: 'no2_ppm') double? no2Ppm,
    String? mode,
  }) = _TelemetryPoint;

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) =>
      _$TelemetryPointFromJson(json);
}
