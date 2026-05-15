import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import 'pill.dart';

class HistoryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final PillTone? badgeTone;
  final String? badgeLabel;

  const HistoryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    this.badgeTone,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AtmosphereTokens.space12,
        horizontal: AtmosphereTokens.space16,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.line2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: c.ink2),
          ),
          const SizedBox(width: AtmosphereTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AtmosphereTextStyles.body(c.ink),
                ),
                const SizedBox(height: AtmosphereTokens.space2),
                Text(
                  sub,
                  style: AtmosphereTextStyles.caption(c.ink3),
                ),
              ],
            ),
          ),
          if (badgeTone != null && badgeLabel != null)
            AtmospherePill(
              label: badgeLabel!,
              tone: badgeTone!,
            ),
        ],
      ),
    );
  }
}
