import 'package:freezed_annotation/freezed_annotation.dart';

part 'command.freezed.dart';
part 'command.g.dart';

@freezed
class Command with _$Command {
  const factory Command({
    required String id,
    required Map<String, dynamic> payload,
    required String status,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'executed_at') DateTime? executedAt,
  }) = _Command;

  factory Command.fromJson(Map<String, dynamic> json) =>
      _$CommandFromJson(json);
}
