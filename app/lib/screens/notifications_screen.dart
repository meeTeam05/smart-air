import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/icons.dart';
import '../design/palette.dart';
import '../design/text_styles.dart';
import '../design/tokens.dart';
import '../widgets/atoms/empty_state.dart';
import '../widgets/shell/atmosphere_app_bar.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const AtmosphereAppBar.brand(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AtmosphereTokens.space16,
              AtmosphereTokens.space20,
              AtmosphereTokens.space16,
              AtmosphereTokens.space12,
            ),
            child: Text(
              'Notifications',
              style: AtmosphereTextStyles.pageTitle(c.ink),
            ),
          ),
          Expanded(
            child: EmptyState(
              icon: AppIcons.notifications,
              title: 'Notifications feed unavailable',
              body:
                  'The current backend does not expose a notifications feed, so this tab now shows the real system state instead of local demo items.',
              primaryAction: 'Open devices',
              onPrimaryAction: () => context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }
}
