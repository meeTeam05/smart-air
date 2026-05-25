import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../core/back_navigation.dart';
import '../../../models/ota.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/ota_provider.dart';
import '../../../services/device_service.dart';
import '../../../widgets/atoms/card.dart';
import '../../../widgets/atoms/empty_state.dart';
import '../../../widgets/atoms/pill.dart';
import '../../../widgets/shell/atmosphere_app_bar.dart';

class OtaScreen extends ConsumerStatefulWidget {
  const OtaScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<OtaScreen> createState() => _OtaScreenState();
}

class _OtaScreenState extends ConsumerState<OtaScreen> {
  String? _submittingVersion;

  Future<void> _startUpdate(String version) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    setState(() => _submittingVersion = version);

    try {
      await ref
          .read(deviceServiceProvider)
          .startOtaUpdate(widget.deviceId, version);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('OTA update requested for $version'),
          backgroundColor: context.colors.brand,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingVersion = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final device = ref
        .watch(devicesProvider)
        .valueOrNull
        ?.where((item) => item.id == widget.deviceId)
        .firstOrNull;
    final otaCatalogAsync = ref.watch(otaCatalogProvider(widget.deviceId));
    final otaCatalog = otaCatalogAsync.valueOrNull;
    final currentVersion =
        device?.firmwareVer ?? otaCatalog?.currentVersion ?? 'Unknown';
    final isOnline = device?.online ?? otaCatalog?.deviceOnline ?? false;

    return BackNavigationScope(
      fallbackRoute: '/devices/${widget.deviceId}/settings',
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AtmosphereAppBar.back(
          title: 'Firmware update',
          onBack: () => handleBackOrFallback(
            context,
            '/devices/${widget.deviceId}/settings',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AtmosphereTokens.space20),
          children: [
            AtmosphereCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current firmware',
                        style: AtmosphereTextStyles.caption(c.ink3),
                      ),
                      AtmospherePill(
                        label: isOnline ? 'Online' : 'Offline',
                        tone: isOnline ? PillTone.online : PillTone.offline,
                      ),
                    ],
                  ),
                  const SizedBox(height: AtmosphereTokens.space4),
                  Text(
                    currentVersion,
                    style: AtmosphereTextStyles.mono(c.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space24),
            Text(
              'Available versions',
              style: AtmosphereTextStyles.h2(c.ink),
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            if (otaCatalogAsync.isLoading && otaCatalog == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AtmosphereTokens.space24,
                  ),
                  child: CircularProgressIndicator(color: c.brand),
                ),
              )
            else if (otaCatalogAsync.hasError && otaCatalog == null)
              EmptyState(
                icon: AppIcons.warn,
                title: 'Failed to load OTA versions',
                body: otaCatalogAsync.error.toString(),
                primaryAction: 'Retry',
                onPrimaryAction: () =>
                    ref.invalidate(otaCatalogProvider(widget.deviceId)),
              )
            else if ((otaCatalog?.versions ?? const <OtaVersionInfo>[]).isEmpty)
              const EmptyState(
                icon: AppIcons.download,
                title: 'No OTA versions found',
                body:
                    'Drop firmware binaries into server/ota-files to make them available here.',
              )
            else
              for (final version in otaCatalog!.versions) ...[
                AtmosphereCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  version.version,
                                  style: AtmosphereTextStyles.body(c.ink),
                                ),
                                if (version.version == currentVersion) ...[
                                  const SizedBox(
                                    width: AtmosphereTokens.space8,
                                  ),
                                  const AtmospherePill(
                                    label: 'Current',
                                    tone: PillTone.brand,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: AtmosphereTokens.space4),
                            Text(
                              version.filename,
                              style: AtmosphereTextStyles.mono(c.ink3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AtmosphereTokens.space12),
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: _submittingVersion == null
                              ? () => _startUpdate(version.version)
                              : null,
                          child: _submittingVersion == version.version
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.paper,
                                  ),
                                )
                              : const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AtmosphereTokens.space12),
              ],
          ],
        ),
      ),
    );
  }
}
