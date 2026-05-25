import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../core/back_navigation.dart';
import '../../../providers/devices_provider.dart';
import '../../../widgets/atoms/card.dart';
import '../../../widgets/atoms/empty_state.dart';
import '../../../widgets/shell/atmosphere_app_bar.dart';

class OtaScreen extends ConsumerWidget {
  const OtaScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final device = ref
        .watch(devicesProvider)
        .valueOrNull
        ?.where((item) => item.id == deviceId)
        .firstOrNull;

    return BackNavigationScope(
      fallbackRoute: '/devices/$deviceId/settings',
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AtmosphereAppBar.back(
          title: 'Firmware update',
          onBack: () =>
              handleBackOrFallback(context, '/devices/$deviceId/settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AtmosphereTokens.space20),
          children: [
            AtmosphereCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current firmware',
                    style: AtmosphereTextStyles.caption(c.ink3),
                  ),
                  const SizedBox(height: AtmosphereTokens.space4),
                  Text(
                    device?.firmwareVer ?? 'Unknown',
                    style: AtmosphereTextStyles.mono(c.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space24),
            const EmptyState(
              icon: AppIcons.download,
              title: 'OTA is not exposed in the app yet',
              body:
                  'The current server accepts OTA via a dedicated MQTT topic, not the generic command API. This screen stays read-only until that app-facing flow exists.',
            ),
          ],
        ),
      ),
    );
  }
}
