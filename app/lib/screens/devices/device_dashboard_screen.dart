import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../models/command.dart';
import '../../models/telemetry.dart';
import '../../providers/devices_provider.dart';
import '../../services/device_service.dart';
import '../../widgets/shell/atmosphere_app_bar.dart';
import '../../widgets/atoms/mode_card.dart';
import '../../widgets/atoms/sensor_tile.dart';
import '../../widgets/atoms/relay_card.dart';
import '../../widgets/atoms/history_row.dart';
import '../../widgets/atoms/pill.dart';
import '../../widgets/atoms/card.dart';

class DeviceDashboardScreen extends ConsumerStatefulWidget {
  const DeviceDashboardScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<DeviceDashboardScreen> createState() =>
      _DeviceDashboardScreenState();
}

class _DeviceDashboardScreenState extends ConsumerState<DeviceDashboardScreen> {
  bool _modeLoading = false;
  final Map<int, bool> _relayLoading = {};
  late TelemetryParams _telemetryParams;
  Timer? _refreshTimer;
  bool _refreshing = false;

  TelemetryParams _buildTelemetryParams() {
    final now = DateTime.now();
    return TelemetryParams(
      deviceId: widget.deviceId,
      from: now.subtract(const Duration(minutes: 30)),
      to: now,
      agg: '1m',
    );
  }

  @override
  void initState() {
    super.initState();
    _telemetryParams = _buildTelemetryParams();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshLiveData());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    final devicesAsync = ref.watch(devicesProvider);
    final device = devicesAsync.valueOrNull
        ?.where((d) => d.id == widget.deviceId)
        .firstOrNull;

    final shadowAsync = ref.watch(shadowProvider(widget.deviceId));
    final shadow = shadowAsync.valueOrNull;

    final reported = shadow?.reported ?? {};
    final reportedMode = (reported['mode'] as String?)?.toLowerCase();
    final mode = reportedMode == 'on' ? 'on' : 'off';
    final isOn = mode.toLowerCase() == 'on';
    final relay1 = reported['relay_1'] as bool? ?? false;
    final relay2 = reported['relay_2'] as bool? ?? false;
    final relay3 = reported['relay_3'] as bool? ?? false;

    final telemetryAsync = ref.watch(telemetryProvider(_telemetryParams));
    final telemetryPoints = telemetryAsync.valueOrNull ?? [];
    final latestTelemetry = _latestTelemetryPoint(telemetryPoints);
    final commandsAsync = ref.watch(commandsProvider(widget.deviceId));
    final recentCommands = commandsAsync.valueOrNull ?? const <Command>[];

    final temp =
        latestTelemetry?.temperature ?? reported['temperature'] as num?;
    final humidity = latestTelemetry?.humidity ?? reported['humidity'] as num?;
    final coPpm = latestTelemetry?.coPpm ?? reported['co_ppm'] as num?;
    final no2Ppm = latestTelemetry?.no2Ppm ?? reported['no2_ppm'] as num?;
    final tempSparkline = telemetryPoints
        .where((p) => p.temperature != null)
        .map((p) => p.temperature!)
        .toList();
    final humiditySparkline = telemetryPoints
        .where((p) => p.humidity != null)
        .map((p) => p.humidity!)
        .toList();
    final coSparkline = telemetryPoints
        .where((p) => p.coPpm != null)
        .map((p) => p.coPpm!)
        .toList();
    final no2Sparkline = telemetryPoints
        .where((p) => p.no2Ppm != null)
        .map((p) => p.no2Ppm!)
        .toList();

    final statusText = device?.online == true
        ? '● ONLINE · ${_relativeTime(device!.lastSeen ?? DateTime.now())}'
        : '● STANDBY · ${_relativeTime(device?.lastSeen ?? DateTime.now())}';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AtmosphereAppBar.back(
        title: device?.name ?? widget.deviceId,
        actions: [
          IconButton(
            icon: Icon(AppIcons.more, color: c.ink),
            tooltip: 'More actions',
            onPressed: () => _showMoreMenu(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshLiveData(refreshDevices: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AtmosphereTokens.space20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactSensors =
                  constraints.maxWidth < 360 || textScale > 1.4;
              final sensorColumns = compactSensors ? 1 : 2;
              final relayColumns = textScale > 1.7
                  ? 1
                  : constraints.maxWidth >= 360
                      ? 2
                      : 1;
              final relayWidth = (constraints.maxWidth -
                      ((relayColumns - 1) * AtmosphereTokens.space12)) /
                  relayColumns;

              final sensorTiles = [
                SensorTile(
                  value: temp?.toStringAsFixed(1),
                  unit: '°C',
                  label: 'Temperature',
                  icon: AppIcons.temp,
                  tone: SensorTone.warm,
                  sparkColor: c.danger,
                  sparklineData:
                      tempSparkline.isNotEmpty ? tempSparkline : null,
                  dimmed: !isOn,
                ),
                SensorTile(
                  value: humidity?.toStringAsFixed(1),
                  unit: '%',
                  label: 'Humidity',
                  icon: AppIcons.humidity,
                  tone: SensorTone.air,
                  sparkColor: c.accent,
                  sparklineData:
                      humiditySparkline.isNotEmpty ? humiditySparkline : null,
                  dimmed: !isOn,
                ),
                SensorTile(
                  value: coPpm?.toStringAsFixed(1),
                  unit: 'ppm',
                  label: 'CO',
                  icon: AppIcons.cloud,
                  tone: SensorTone.cool,
                  sparkColor: c.brand,
                  sparklineData: coSparkline.isNotEmpty ? coSparkline : null,
                  dimmed: !isOn,
                ),
                SensorTile(
                  value: no2Ppm?.toStringAsFixed(1),
                  unit: 'ppm',
                  label: 'NO₂',
                  icon: AppIcons.smog,
                  tone: SensorTone.no2,
                  sparkColor: const Color(0xFF7A4FD0),
                  sparklineData: no2Sparkline.isNotEmpty ? no2Sparkline : null,
                  dimmed: !isOn,
                ),
              ];

              final relayCards = [
                RelayCard(
                  channel: 1,
                  name: 'Fan',
                  on: relay1,
                  disabled: !isOn || _relayLoading[1] == true,
                  onTap: () => _handleRelayToggle(1, relay1, isOn),
                ),
                RelayCard(
                  channel: 2,
                  name: 'Lamp',
                  on: relay2,
                  disabled: !isOn || _relayLoading[2] == true,
                  onTap: () => _handleRelayToggle(2, relay2, isOn),
                ),
                RelayCard(
                  channel: 3,
                  name: 'Filter',
                  on: relay3,
                  disabled: !isOn || _relayLoading[3] == true,
                  onTap: () => _handleRelayToggle(3, relay3, isOn),
                ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(0),
                    header: true,
                    label: '${device?.name ?? widget.deviceId}, $statusText',
                    child: ExcludeSemantics(
                      child: Text(
                        statusText,
                        style: AtmosphereTextStyles.caption(c.ink3),
                      ),
                    ),
                  ),
                  const SizedBox(height: AtmosphereTokens.space16),
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(1),
                    child: DeviceModeCard(
                      mode: mode,
                      online: device?.online ?? false,
                      onChanged: _modeLoading
                          ? null
                          : (value) => _handleModeToggle(value),
                    ),
                  ),
                  const SizedBox(height: AtmosphereTokens.space20),
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(2),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: sensorColumns,
                        mainAxisSpacing: AtmosphereTokens.space12,
                        crossAxisSpacing: AtmosphereTokens.space12,
                        mainAxisExtent: compactSensors ? 176 : 168,
                      ),
                      itemCount: sensorTiles.length,
                      itemBuilder: (context, index) => sensorTiles[index],
                    ),
                  ),
                  const SizedBox(height: AtmosphereTokens.space24),
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AtmosphereTokens.space8,
                          runSpacing: AtmosphereTokens.space4,
                          children: [
                            Text(
                              'Relays',
                              style: AtmosphereTextStyles.h2(c.ink),
                            ),
                            Text(
                              '· 3 channels',
                              style: AtmosphereTextStyles.caption(c.ink3),
                            ),
                          ],
                        ),
                        const SizedBox(height: AtmosphereTokens.space12),
                        Wrap(
                          spacing: AtmosphereTokens.space12,
                          runSpacing: AtmosphereTokens.space12,
                          children: relayCards
                              .map(
                                (card) => SizedBox(
                                  width: relayWidth,
                                  child: card,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AtmosphereTokens.space24),
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(4),
                    child: AtmosphereCard(
                      padding: const EdgeInsets.all(AtmosphereTokens.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Recent activity',
                                  style: AtmosphereTextStyles.h2(c.ink),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push(
                                    '/devices/${widget.deviceId}/commands'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AtmosphereTokens.space12,
                                    vertical: AtmosphereTokens.space8,
                                  ),
                                ),
                                child: Text(
                                  'View all →',
                                  style: AtmosphereTextStyles.body(c.brand),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AtmosphereTokens.space8),
                          if (recentCommands.isEmpty)
                            Text(
                              commandsAsync.isLoading
                                  ? 'Loading command activity...'
                                  : 'No command activity yet.',
                              style: AtmosphereTextStyles.body(c.ink2),
                            )
                          else
                            ...recentCommands.take(3).map(
                              (command) {
                                final (icon, label) =
                                    _formatRecentActivity(command);
                                final (tone, badgeLabel) =
                                    _statusBadge(command.status);
                                return HistoryRow(
                                  icon: icon,
                                  label: label,
                                  sub: _relativeTime(command.createdAt),
                                  badgeTone: tone,
                                  badgeLabel: badgeLabel,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  (IconData, String) _formatRecentActivity(Command command) {
    final payload = command.payload;
    final type = payload['type'] as String? ?? 'unknown';
    return switch (type) {
      'device_mode' =>
        (AppIcons.bolt, 'Mode changed to ${(payload['mode'] ?? '?').toString().toUpperCase()}'),
      'relay_set' => (
          AppIcons.wind,
          'Relay ${payload['relay'] ?? '?'} turned ${payload['state'] == true ? 'on' : 'off'}',
        ),
      'calibrate_co' => (AppIcons.cog, 'CO calibration requested'),
      'calibrate_no2' => (AppIcons.cog, 'NO2 calibration requested'),
      _ => (AppIcons.device, type),
    };
  }

  (PillTone, String) _statusBadge(String status) {
    return switch (status) {
      'done' => (PillTone.online, 'Done'),
      'sent' => (PillTone.brand, 'Sent'),
      'error' => (PillTone.danger, 'Error'),
      'timeout' => (PillTone.warn, 'Timeout'),
      _ => (PillTone.accent, 'Pending'),
    };
  }

  TelemetryPoint? _latestTelemetryPoint(List<TelemetryPoint> points) {
    TelemetryPoint? latest;
    for (final point in points) {
      if (latest == null || point.ts.isAfter(latest.ts)) {
        latest = point;
      }
    }
    return latest;
  }

  Future<void> _refreshLiveData({bool refreshDevices = false}) async {
    if (_refreshing) return;
    _refreshing = true;

    final params = _buildTelemetryParams();
    if (mounted) {
      setState(() => _telemetryParams = params);
    }

    try {
      await Future.wait([
        if (refreshDevices) ref.refresh(devicesProvider.future),
        ref.refresh(shadowProvider(widget.deviceId).future),
        ref.refresh(telemetryProvider(params).future),
        ref.refresh(commandsProvider(widget.deviceId).future),
      ]);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _waitForCommandAndRefresh(String commandId) async {
    ref.invalidate(commandsProvider(widget.deviceId));
    final command = await ref.read(deviceServiceProvider).waitForCommandCompletion(
          widget.deviceId,
          commandId,
          timeout: const Duration(seconds: 30),
          pollInterval: const Duration(seconds: 2),
        );
    await _refreshLiveData();
    if (command.status != 'done') {
      throw StateError('Command finished with status ${command.status}');
    }
  }

  Future<void> _handleModeToggle(bool value) async {
    final newMode = value ? 'on' : 'off';

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch to Standby?'),
          content: const Text(
            'Sensors will pause and relays will turn off.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _modeLoading = true);

    try {
      final commandId =
          await ref.read(deviceServiceProvider).setMode(widget.deviceId, newMode);
      await _waitForCommandAndRefresh(commandId);
    } catch (e) {
      if (mounted) {
        final c = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change mode: $e'),
            backgroundColor: c.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _modeLoading = false);
    }
  }

  Future<void> _handleRelayToggle(
      int channel, bool currentState, bool deviceOn) async {
    if (!deviceOn) {
      final c = context.colors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Turn device on first'),
          backgroundColor: c.warn,
        ),
      );
      return;
    }

    setState(() => _relayLoading[channel] = true);

    try {
      final commandId = await ref
          .read(deviceServiceProvider)
          .setRelay(widget.deviceId, channel, !currentState);
      await _waitForCommandAndRefresh(commandId);
    } catch (e) {
      if (mounted) {
        final c = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle relay: $e'),
            backgroundColor: c.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _relayLoading[channel] = false);
      }
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.chart),
              title: const Text('View charts'),
              onTap: () {
                Navigator.pop(context);
                context.push('/devices/${widget.deviceId}/chart');
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.cog),
              title: const Text('Device settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/devices/${widget.deviceId}/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
