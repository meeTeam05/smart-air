// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HomeImpl _$$HomeImplFromJson(Map<String, dynamic> json) => _$HomeImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      ownerId: json['owner_id'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
    );

Map<String, dynamic> _$$HomeImplToJson(_$HomeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'owner_id': instance.ownerId,
      'timezone': instance.timezone,
    };

_$RoomImpl _$$RoomImplFromJson(Map<String, dynamic> json) => _$RoomImpl(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
    );

Map<String, dynamic> _$$RoomImplToJson(_$RoomImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'home_id': instance.homeId,
      'name': instance.name,
      'icon': instance.icon,
    };
