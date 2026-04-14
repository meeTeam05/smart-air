import 'package:freezed_annotation/freezed_annotation.dart';

part 'home.freezed.dart';
part 'home.g.dart';

@freezed
class Home with _$Home {
  const factory Home({
    required String id,
    required String name,
    String? address,
    @JsonKey(name: 'owner_id') String? ownerId,
    @Default('Asia/Ho_Chi_Minh') String timezone,
  }) = _Home;

  factory Home.fromJson(Map<String, dynamic> json) => _$HomeFromJson(json);
}

@freezed
class Room with _$Room {
  const factory Room({
    required String id,
    @JsonKey(name: 'home_id') required String homeId,
    required String name,
    String? icon,
  }) = _Room;

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
}
