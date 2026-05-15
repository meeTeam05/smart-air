// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TelemetryPointImpl _$$TelemetryPointImplFromJson(Map<String, dynamic> json) =>
    _$TelemetryPointImpl(
      ts: DateTime.parse(json['ts'] as String),
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      coPpm: (json['co_ppm'] as num?)?.toDouble(),
      no2Ppm: (json['no2_ppm'] as num?)?.toDouble(),
      mode: json['mode'] as String?,
    );

Map<String, dynamic> _$$TelemetryPointImplToJson(
        _$TelemetryPointImpl instance) =>
    <String, dynamic>{
      'ts': instance.ts.toIso8601String(),
      'temperature': instance.temperature,
      'humidity': instance.humidity,
      'co_ppm': instance.coPpm,
      'no2_ppm': instance.no2Ppm,
      'mode': instance.mode,
    };
