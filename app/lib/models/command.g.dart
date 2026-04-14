// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CommandImpl _$$CommandImplFromJson(Map<String, dynamic> json) =>
    _$CommandImpl(
      id: json['id'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      executedAt: json['executed_at'] == null
          ? null
          : DateTime.parse(json['executed_at'] as String),
    );

Map<String, dynamic> _$$CommandImplToJson(_$CommandImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'payload': instance.payload,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
      'executed_at': instance.executedAt?.toIso8601String(),
    };
