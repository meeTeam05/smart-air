class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.deviceId,
    required this.deviceName,
    required this.title,
    required this.body,
    required this.severity,
    required this.occurredAt,
    this.payload = const {},
  });

  final String id;
  final String type;
  final String deviceId;
  final String deviceName;
  final String title;
  final String body;
  final String severity;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final occurredAtRaw = json['occurred_at'];
    final occurredAt = occurredAtRaw is String
        ? DateTime.tryParse(occurredAtRaw)?.toLocal()
        : null;

    return NotificationItem(
      id: json['id'].toString(),
      type: json['type'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      occurredAt: occurredAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }
}
