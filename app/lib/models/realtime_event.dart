enum RealtimeStatus {
  disconnected,
  connecting,
  connected,
  degraded,
}

class RealtimeEvent {
  const RealtimeEvent({
    required this.id,
    required this.type,
    required this.deviceId,
    required this.occurredAt,
    required this.payload,
  });

  final String id;
  final String type;
  final String deviceId;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      id: json['id'].toString(),
      type: json['type'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }
}
