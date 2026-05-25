import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/back_navigation.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import '../../design/icons.dart';
import '../../models/command.dart';
import '../../providers/devices_provider.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/atoms/filter_chip.dart';
import '../../widgets/atoms/history_row.dart';
import '../../widgets/atoms/pill.dart';
import '../../widgets/atoms/empty_state.dart';
import '../../widgets/shell/atmosphere_app_bar.dart';

enum _CommandFilter { all, done, failed, pending }

class CommandHistoryScreen extends ConsumerStatefulWidget {
  const CommandHistoryScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<CommandHistoryScreen> createState() =>
      _CommandHistoryScreenState();
}

class _CommandHistoryScreenState extends ConsumerState<CommandHistoryScreen> {
  _CommandFilter _filter = _CommandFilter.all;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final commands = ref.watch(commandsProvider(widget.deviceId));

    return BackNavigationScope(
      fallbackRoute: '/devices/${widget.deviceId}',
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AtmosphereAppBar.back(
          title: 'Command history',
          onBack: () =>
              handleBackOrFallback(context, '/devices/${widget.deviceId}'),
        ),
        body: Column(
          children: [
            const SizedBox(height: AtmosphereTokens.space16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AtmosphereTokens.space16),
              child: Row(
                children: [
                  AtmosphereFilterChip(
                    label: 'All',
                    active: _filter == _CommandFilter.all,
                    onTap: () => setState(() => _filter = _CommandFilter.all),
                  ),
                  const SizedBox(width: AtmosphereTokens.space8),
                  AtmosphereFilterChip(
                    label: 'Done',
                    active: _filter == _CommandFilter.done,
                    onTap: () => setState(() => _filter = _CommandFilter.done),
                  ),
                  const SizedBox(width: AtmosphereTokens.space8),
                  AtmosphereFilterChip(
                    label: 'Failed',
                    active: _filter == _CommandFilter.failed,
                    onTap: () =>
                        setState(() => _filter = _CommandFilter.failed),
                  ),
                  const SizedBox(width: AtmosphereTokens.space8),
                  AtmosphereFilterChip(
                    label: 'Pending',
                    active: _filter == _CommandFilter.pending,
                    onTap: () =>
                        setState(() => _filter = _CommandFilter.pending),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(commandsProvider(widget.deviceId)),
                child: AsyncValueWidget(
                  value: commands,
                  data: (list) {
                    final filtered = _filterCommands(list);
                    if (filtered.isEmpty) {
                      return const EmptyState(
                        icon: AppIcons.chart,
                        title: 'No commands yet',
                        body:
                            'Command history will appear here once you interact with the device.',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AtmosphereTokens.space16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _CommandRow(cmd: filtered[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Command> _filterCommands(List<Command> commands) {
    return switch (_filter) {
      _CommandFilter.all => commands,
      _CommandFilter.done => commands.where((c) => c.status == 'done').toList(),
      _CommandFilter.failed => commands
          .where((c) => c.status == 'error' || c.status == 'timeout')
          .toList(),
      _CommandFilter.pending => commands
          .where((c) => c.status == 'pending' || c.status == 'sent')
          .toList(),
    };
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.cmd});
  final Command cmd;

  @override
  Widget build(BuildContext context) {
    final (icon, label, sub) = _formatCommand(cmd);
    final (tone, badgeLabel) = _statusBadge(cmd.status);

    return GestureDetector(
      onTap: () => _showPayloadSheet(context, cmd),
      child: HistoryRow(
        icon: icon,
        label: label,
        sub: sub,
        badgeTone: tone,
        badgeLabel: badgeLabel,
      ),
    );
  }

  (IconData, String, String) _formatCommand(Command cmd) {
    final payload = cmd.payload;
    final type = payload['type'] ?? 'unknown';

    final icon = switch (type) {
      'device_mode' => AppIcons.bolt,
      'relay_set' => AppIcons.wind,
      'calibrate_co' || 'calibrate_no2' => AppIcons.cog,
      _ => AppIcons.device,
    };

    final label = switch (type) {
      'device_mode' => 'Mode: ${payload['mode'] ?? '?'}',
      'relay_set' =>
        'Relay ${payload['relay'] ?? '?'}: ${payload['state'] == true ? 'ON' : 'OFF'}',
      'calibrate_co' => 'Calibrate CO sensor',
      'calibrate_no2' => 'Calibrate NO₂ sensor',
      _ => type,
    };

    final sub = _formatTime(cmd.createdAt);
    return (icon, label, sub);
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

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showPayloadSheet(BuildContext context, Command cmd) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = sheetContext.colors;

        return Container(
          decoration: BoxDecoration(
            color: c.paper,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AtmosphereTokens.radiusCard)),
          ),
          padding: const EdgeInsets.all(AtmosphereTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Command payload', style: AtmosphereTextStyles.h2(c.ink)),
              const SizedBox(height: AtmosphereTokens.space16),
              Container(
                padding: const EdgeInsets.all(AtmosphereTokens.space12),
                decoration: BoxDecoration(
                  color: c.line2,
                  borderRadius:
                      BorderRadius.circular(AtmosphereTokens.radiusInput),
                ),
                child: SelectableText(
                  cmd.payload.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                  style: AtmosphereTextStyles.mono(c.ink2, size: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
