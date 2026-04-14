import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Card shown in the 2-column device grid on HomeScreen.
class DeviceCard extends StatelessWidget {
  final String name;
  final String room;
  final bool isOnline;
  final bool isProvisioned; // false = WiFi not yet configured
  final String? temperature;
  final String? humidity;

  const DeviceCard({
    super.key,
    required this.name,
    required this.room,
    this.isOnline = false,
    this.isProvisioned = false,
    this.temperature,
    this.humidity,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main card ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !isProvisioned
                  ? Colors.orange.withValues(alpha: 0.5)
                  : isOnline
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : c.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Device image — fills top 60% of card ─────────────────────
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15)),
                  child: Container(
                    color: c.surfaceVar,
                    child: Image.asset(
                      'assets/images/device_placeholder.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.devices,
                        size: 48,
                        color: isOnline
                            ? AppColors.primary
                            : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Bottom info strip ─────────────────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sensor values (when online + available)
                      if (isOnline &&
                          (temperature != null || humidity != null)) ...[
                        Row(
                          children: [
                            if (temperature != null) ...[
                              const Icon(Icons.thermostat,
                                  size: 12,
                                  color: AppColors.warning),
                              const SizedBox(width: 2),
                              Text(
                                '$temperature°',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: c.textSecondary),
                              ),
                            ],
                            if (temperature != null &&
                                humidity != null)
                              const SizedBox(width: 6),
                            if (humidity != null) ...[
                              const Icon(Icons.water_drop,
                                  size: 12,
                                  color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                '$humidity%',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: c.textSecondary),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],

                      // Device name
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Room + status dot
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: c.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline
                                  ? AppColors.online
                                  : AppColors.offline,
                              boxShadow: isOnline
                                  ? [
                                      BoxShadow(
                                        color: AppColors.online
                                            .withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── "Setup Wi-Fi" badge ───────────────────────────────────────────
        if (!isProvisioned)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.4),
                    blurRadius: 6,
                  )
                ],
              ),
              child: const Text(
                'Setup Wi-Fi',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
