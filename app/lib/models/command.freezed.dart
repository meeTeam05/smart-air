// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Command _$CommandFromJson(Map<String, dynamic> json) {
  return _Command.fromJson(json);
}

/// @nodoc
mixin _$Command {
  String get id => throw _privateConstructorUsedError;
  Map<String, dynamic> get payload => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'executed_at')
  DateTime? get executedAt => throw _privateConstructorUsedError;

  /// Serializes this Command to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Command
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommandCopyWith<Command> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommandCopyWith<$Res> {
  factory $CommandCopyWith(Command value, $Res Function(Command) then) =
      _$CommandCopyWithImpl<$Res, Command>;
  @useResult
  $Res call(
      {String id,
      Map<String, dynamic> payload,
      String status,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'executed_at') DateTime? executedAt});
}

/// @nodoc
class _$CommandCopyWithImpl<$Res, $Val extends Command>
    implements $CommandCopyWith<$Res> {
  _$CommandCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Command
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? payload = null,
    Object? status = null,
    Object? createdAt = null,
    Object? executedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      payload: null == payload
          ? _value.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      executedAt: freezed == executedAt
          ? _value.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommandImplCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory _$$CommandImplCopyWith(
          _$CommandImpl value, $Res Function(_$CommandImpl) then) =
      __$$CommandImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      Map<String, dynamic> payload,
      String status,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'executed_at') DateTime? executedAt});
}

/// @nodoc
class __$$CommandImplCopyWithImpl<$Res>
    extends _$CommandCopyWithImpl<$Res, _$CommandImpl>
    implements _$$CommandImplCopyWith<$Res> {
  __$$CommandImplCopyWithImpl(
      _$CommandImpl _value, $Res Function(_$CommandImpl) _then)
      : super(_value, _then);

  /// Create a copy of Command
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? payload = null,
    Object? status = null,
    Object? createdAt = null,
    Object? executedAt = freezed,
  }) {
    return _then(_$CommandImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      payload: null == payload
          ? _value._payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      executedAt: freezed == executedAt
          ? _value.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CommandImpl implements _Command {
  const _$CommandImpl(
      {required this.id,
      required final Map<String, dynamic> payload,
      required this.status,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'executed_at') this.executedAt})
      : _payload = payload;

  factory _$CommandImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommandImplFromJson(json);

  @override
  final String id;
  final Map<String, dynamic> _payload;
  @override
  Map<String, dynamic> get payload {
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_payload);
  }

  @override
  final String status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'executed_at')
  final DateTime? executedAt;

  @override
  String toString() {
    return 'Command(id: $id, payload: $payload, status: $status, createdAt: $createdAt, executedAt: $executedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommandImpl &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      const DeepCollectionEquality().hash(_payload),
      status,
      createdAt,
      executedAt);

  /// Create a copy of Command
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommandImplCopyWith<_$CommandImpl> get copyWith =>
      __$$CommandImplCopyWithImpl<_$CommandImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommandImplToJson(
      this,
    );
  }
}

abstract class _Command implements Command {
  const factory _Command(
          {required final String id,
          required final Map<String, dynamic> payload,
          required final String status,
          @JsonKey(name: 'created_at') required final DateTime createdAt,
          @JsonKey(name: 'executed_at') final DateTime? executedAt}) =
      _$CommandImpl;

  factory _Command.fromJson(Map<String, dynamic> json) = _$CommandImpl.fromJson;

  @override
  String get id;
  @override
  Map<String, dynamic> get payload;
  @override
  String get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'executed_at')
  DateTime? get executedAt;

  /// Create a copy of Command
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommandImplCopyWith<_$CommandImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
