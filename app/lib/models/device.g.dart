// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeviceImpl _$$DeviceImplFromJson(Map<String, dynamic> json) => _$DeviceImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      homeId: json['home_id'] as String,
      roomId: json['room_id'] as String?,
      online: json['online'] as bool? ?? false,
      lastSeen: json['last_seen'] == null
          ? null
          : DateTime.parse(json['last_seen'] as String),
      firmwareVer: json['firmware_ver'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$DeviceImplToJson(_$DeviceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'home_id': instance.homeId,
      'room_id': instance.roomId,
      'online': instance.online,
      'last_seen': instance.lastSeen?.toIso8601String(),
      'firmware_ver': instance.firmwareVer,
      'created_at': instance.createdAt?.toIso8601String(),
    };

_$DeviceShadowImpl _$$DeviceShadowImplFromJson(Map<String, dynamic> json) =>
    _$DeviceShadowImpl(
      reported: json['reported'] as Map<String, dynamic>? ?? const {},
      desired: json['desired'] as Map<String, dynamic>? ?? const {},
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$DeviceShadowImplToJson(_$DeviceShadowImpl instance) =>
    <String, dynamic>{
      'reported': instance.reported,
      'desired': instance.desired,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
