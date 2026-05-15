import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/icons.dart';
import '../design/palette.dart';
import '../design/text_styles.dart';
import '../design/tokens.dart';
import '../widgets/atoms/empty_state.dart';
import '../widgets/shell/atmosphere_app_bar.dart';

class AutomationScreen extends StatelessWidget {
  const AutomationScreen({super.key});

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
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automations',
                  style: AtmosphereTextStyles.pageTitle(c.ink),
                ),
                const SizedBox(height: AtmosphereTokens.space8),
                Text(
                  'Rules are not exposed by the current backend yet.',
                  style: AtmosphereTextStyles.body(c.ink2),
                ),
              ],
            ),
          ),
          Expanded(
            child: EmptyState(
              icon: AppIcons.bolt,
              title: 'Automation is unavailable',
              body:
                  'The current server does not expose automation rules yet, so this tab no longer shows local-only placeholder data.',
              primaryAction: 'Open devices',
              onPrimaryAction: () => context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }
}
