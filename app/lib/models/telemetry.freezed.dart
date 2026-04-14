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
  double get temperature => throw _privateConstructorUsedError;
  double get humidity => throw _privateConstructorUsedError;

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
  $Res call({DateTime ts, double temperature, double humidity});
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
    Object? temperature = null,
    Object? humidity = null,
  }) {
    return _then(_value.copyWith(
      ts: null == ts
          ? _value.ts
          : ts // ignore: cast_nullable_to_non_nullable
              as DateTime,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
      humidity: null == humidity
          ? _value.humidity
          : humidity // ignore: cast_nullable_to_non_nullable
              as double,
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
  $Res call({DateTime ts, double temperature, double humidity});
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
    Object? temperature = null,
    Object? humidity = null,
  }) {
    return _then(_$TelemetryPointImpl(
      ts: null == ts
          ? _value.ts
          : ts // ignore: cast_nullable_to_non_nullable
              as DateTime,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
      humidity: null == humidity
          ? _value.humidity
          : humidity // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TelemetryPointImpl implements _TelemetryPoint {
  const _$TelemetryPointImpl(
      {required this.ts, required this.temperature, required this.humidity});

  factory _$TelemetryPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$TelemetryPointImplFromJson(json);

  @override
  final DateTime ts;
  @override
  final double temperature;
  @override
  final double humidity;

  @override
  String toString() {
    return 'TelemetryPoint(ts: $ts, temperature: $temperature, humidity: $humidity)';
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
                other.humidity == humidity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, ts, temperature, humidity);

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
      required final double temperature,
      required final double humidity}) = _$TelemetryPointImpl;

  factory _TelemetryPoint.fromJson(Map<String, dynamic> json) =
      _$TelemetryPointImpl.fromJson;

  @override
  DateTime get ts;
  @override
  double get temperature;
  @override
  double get humidity;

  /// Create a copy of TelemetryPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TelemetryPointImplCopyWith<_$TelemetryPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
