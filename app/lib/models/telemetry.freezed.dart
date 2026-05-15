// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telemetry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TelemetryPoint _$TelemetryPointFromJson(Map<String, dynamic> json) {
  return _TelemetryPoint.fromJson(json);
}

/// @nodoc
mixin _$TelemetryPoint {
  DateTime get ts => throw _privateConstructorUsedError;
  double? get temperature => throw _privateConstructorUsedError;
  double? get humidity => throw _privateConstructorUsedError;
  @JsonKey(name: 'co_ppm')
  double? get coPpm => throw _privateConstructorUsedError;
  @JsonKey(name: 'no2_ppm')
  double? get no2Ppm => throw _privateConstructorUsedError;
  String? get mode => throw _privateConstructorUsedError;

  /// Serializes this TelemetryPoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TelemetryPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TelemetryPointCopyWith<TelemetryPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TelemetryPointCopyWith<$Res> {
  factory $TelemetryPointCopyWith(
          TelemetryPoint value, $Res Function(TelemetryPoint) then) =
      _$TelemetryPointCopyWithImpl<$Res, TelemetryPoint>;
  @useResult
  $Res call(
      {DateTime ts,
      double? temperature,
      double? humidity,
      @JsonKey(name: 'co_ppm') double? coPpm,
      @JsonKey(name: 'no2_ppm') double? no2Ppm,
      String? mode});
}

/// @nodoc
class _$TelemetryPointCopyWithImpl<$Res, $Val extends TelemetryPoint>
    implements $TelemetryPointCopyWith<$Res> {
  _$TelemetryPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TelemetryPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ts = null,
    Object? temperature = freezed,
    Object? humidity = freezed,
    Object? coPpm = freezed,
    Object? no2Ppm = freezed,
    Object? mode = freezed,
  }) {
    return _then(_value.copyWith(
      ts: null == ts
          ? _value.ts
          : ts // ignore: cast_nullable_to_non_nullable
              as DateTime,
      temperature: freezed == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double?,
      humidity: freezed == humidity
          ? _value.humidity
          : humidity // ignore: cast_nullable_to_non_nullable
              as double?,
      coPpm: freezed == coPpm
          ? _value.coPpm
          : coPpm // ignore: cast_nullable_to_non_nullable
              as double?,
      no2Ppm: freezed == no2Ppm
          ? _value.no2Ppm
          : no2Ppm // ignore: cast_nullable_to_non_nullable
              as double?,
      mode: freezed == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TelemetryPointImplCopyWith<$Res>
    implements $TelemetryPointCopyWith<$Res> {
  factory _$$TelemetryPointImplCopyWith(_$TelemetryPointImpl value,
          $Res Function(_$TelemetryPointImpl) then) =
      __$$TelemetryPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime ts,
      double? temperature,
      double? humidity,
      @JsonKey(name: 'co_ppm') double? coPpm,
      @JsonKey(name: 'no2_ppm') double? no2Ppm,
      String? mode});
}

/// @nodoc
class __$$TelemetryPointImplCopyWithImpl<$Res>
    extends _$TelemetryPointCopyWithImpl<$Res, _$TelemetryPointImpl>
    implements _$$TelemetryPointImplCopyWith<$Res> {
  __$$TelemetryPointImplCopyWithImpl(
      _$TelemetryPointImpl _value, $Res Function(_$TelemetryPointImpl) _then)
      : super(_value, _then);

  /// Create a copy of TelemetryPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ts = null,
    Object? temperature = freezed,
    Object? humidity = freezed,
    Object? coPpm = freezed,
    Object? no2Ppm = freezed,
    Object? mode = freezed,
  }) {
    return _then(_$TelemetryPointImpl(
      ts: null == ts
          ? _value.ts
          : ts // ignore: cast_nullable_to_non_nullable
              as DateTime,
      temperature: freezed == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double?,
      humidity: freezed == humidity
          ? _value.humidity
          : humidity // ignore: cast_nullable_to_non_nullable
              as double?,
      coPpm: freezed == coPpm
          ? _value.coPpm
          : coPpm // ignore: cast_nullable_to_non_nullable
              as double?,
      no2Ppm: freezed == no2Ppm
          ? _value.no2Ppm
          : no2Ppm // ignore: cast_nullable_to_non_nullable
              as double?,
      mode: freezed == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TelemetryPointImpl implements _TelemetryPoint {
  const _$TelemetryPointImpl(
      {required this.ts,
      this.temperature,
      this.humidity,
      @JsonKey(name: 'co_ppm') this.coPpm,
      @JsonKey(name: 'no2_ppm') this.no2Ppm,
      this.mode});

  factory _$TelemetryPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$TelemetryPointImplFromJson(json);

  @override
  final DateTime ts;
  @override
  final double? temperature;
  @override
  final double? humidity;
  @override
  @JsonKey(name: 'co_ppm')
  final double? coPpm;
  @override
  @JsonKey(name: 'no2_ppm')
  final double? no2Ppm;
  @override
  final String? mode;

  @override
  String toString() {
    return 'TelemetryPoint(ts: $ts, temperature: $temperature, humidity: $humidity, coPpm: $coPpm, no2Ppm: $no2Ppm, mode: $mode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TelemetryPointImpl &&
            (identical(other.ts, ts) || other.ts == ts) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.humidity, humidity) ||
                other.humidity == humidity) &&
            (identical(other.coPpm, coPpm) || other.coPpm == coPpm) &&
            (identical(other.no2Ppm, no2Ppm) || other.no2Ppm == no2Ppm) &&
            (identical(other.mode, mode) || other.mode == mode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, ts, temperature, humidity, coPpm, no2Ppm, mode);

  /// Create a copy of TelemetryPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TelemetryPointImplCopyWith<_$TelemetryPointImpl> get copyWith =>
      __$$TelemetryPointImplCopyWithImpl<_$TelemetryPointImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TelemetryPointImplToJson(
      this,
    );
  }
}

abstract class _TelemetryPoint implements TelemetryPoint {
  const factory _TelemetryPoint(
      {required final DateTime ts,
      final double? temperature,
      final double? humidity,
      @JsonKey(name: 'co_ppm') final double? coPpm,
      @JsonKey(name: 'no2_ppm') final double? no2Ppm,
      final String? mode}) = _$TelemetryPointImpl;

  factory _TelemetryPoint.fromJson(Map<String, dynamic> json) =
      _$TelemetryPointImpl.fromJson;

  @override
  DateTime get ts;
  @override
  double? get temperature;
  @override
  double? get humidity;
  @override
  @JsonKey(name: 'co_ppm')
  double? get coPpm;
  @override
  @JsonKey(name: 'no2_ppm')
  double? get no2Ppm;
  @override
  String? get mode;

  /// Create a copy of TelemetryPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TelemetryPointImplCopyWith<_$TelemetryPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
