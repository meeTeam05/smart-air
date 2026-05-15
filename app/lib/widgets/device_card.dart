import 'package:flutter/material.dart';
import '../design/palette.dart';
import '../design/tokens.dart';
import '../design/text_styles.dart';
import '../design/icons.dart';
import '../models/device.dart';
import '../widgets/atoms/pill.dart';
import '../widgets/atoms/ghost_button.dart';

/// Device card for Home tab list.
/// Matches Phase 6 spec: tint bg, status pill, room/wifi info, view detail button.
class DeviceCard extends StatelessWidget {
  final Device device;
  final String? roomName;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.roomName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final tintColor = _getTintColor(device.id, c);

    return Container(
      decoration: BoxDecoration(
        color: tintColor.bg,
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
        border: Border.all(color: c.line, width: 1),
      ),
      padding: const EdgeInsets.all(AtmosphereTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + name + mode badge + status pill
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tintColor.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AppIcons.device,
                  color: c.ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: AtmosphereTokens.space12),
              Expanded(
                child: Text(
                  device.name,
                  style: AtmosphereTextStyles.h2(c.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AtmosphereTokens.space8),
              if (device.mode != null) ...[
                AtmospherePill(
                  label: device.mode!.toUpperCase(),
                  tone:
                      device.mode == 'on' ? PillTone.online : PillTone.offline,
                ),
                const SizedBox(width: AtmosphereTokens.space8),
              ],
              AtmospherePill(
                label: device.online ? 'Online' : 'Offline',
                tone: device.online ? PillTone.online : PillTone.offline,
              ),
            ],
          ),
          const SizedBox(height: AtmosphereTokens.space16),
          // Room info
          Row(
            children: [
              Icon(AppIcons.pin, size: 14, color: c.ink3),
              const SizedBox(width: AtmosphereTokens.space6),
              Text(
                roomName ??
                    (device.roomId == null
                        ? 'No room assigned'
                        : 'Room unavailable'),
                style: AtmosphereTextStyles.caption(c.ink2),
              ),
            ],
          ),
          const SizedBox(height: AtmosphereTokens.space20),
          // View Detail button
          SizedBox(
            width: double.infinity,
            child: GhostButton(
              label: 'View Detail',
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }

  /// Generate tint color based on device ID hash.
  /// Returns 4-tone palette rotation: brand, accent, mint, no2.
  ({Color bg, Color accent}) _getTintColor(String id, AtmospherePalette c) {
    final hash = id.hashCode.abs() % 4;
    switch (hash) {
      case 0:
        return (bg: c.brandTint, accent: c.brand);
      case 1:
        return (bg: c.accentTint, accent: c.accent);
      case 2:
        return (bg: c.mint.withValues(alpha: 0.2), accent: c.brand);
      case 3:
        return (bg: const Color(0xFFF0E8FB), accent: const Color(0xFF7A4FD0));
      default:
        return (bg: c.brandTint, accent: c.brand);
    }
  }
}

