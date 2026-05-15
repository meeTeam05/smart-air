import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app_theme.dart';
import '../../../models/device.dart';
import '../../../models/home.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/homes_provider.dart';
import '../../../services/device_service.dart';
import '../../../widgets/atoms/empty_state.dart';
import '../../../widgets/shell/atmosphere_app_bar.dart';
import '../../../widgets/atoms/card.dart';
import '../../../widgets/atoms/pill.dart';
import '../../../widgets/atoms/danger_button.dart';

class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<GeneralSettingsScreen> createState() =>
      _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  final _nameController = TextEditingController();
  bool _editingName = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final devicesAsync = ref.watch(devicesProvider);
    if (devicesAsync.isLoading && devicesAsync.valueOrNull == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: const AtmosphereAppBar.back(title: 'Settings'),
        body: Center(child: CircularProgressIndicator(color: c.brand)),
      );
    }
    if (devicesAsync.hasError) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: const AtmosphereAppBar.back(title: 'Settings'),
        body: EmptyState(
          icon: AppIcons.warn,
          title: 'Failed to load device',
          body: devicesAsync.error.toString(),
          primaryAction: 'Retry',
          onPrimaryAction: () => ref.invalidate(devicesProvider),
          secondaryAction: 'Go home',
          onSecondaryAction: () => context.go('/home'),
        ),
      );
    }

    final device = devicesAsync.valueOrNull
        ?.where((d) => d.id == widget.deviceId)
        .firstOrNull;

    if (device == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: const AtmosphereAppBar.back(title: 'Settings'),
        body: EmptyState(
          icon: AppIcons.device,
          title: 'Device not found',
          body: 'This device may have been removed or is no longer available.',
          primaryAction: 'Refresh',
          onPrimaryAction: () => ref.invalidate(devicesProvider),
          secondaryAction: 'Go home',
          onSecondaryAction: () => context.go('/home'),
        ),
      );
    }

    final roomsAsync = ref.watch(roomsProvider(device.homeId));
    final rooms = roomsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const AtmosphereAppBar.back(title: 'Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AtmosphereTokens.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General section
            Text(
              'General',
              style: AtmosphereTextStyles.h2(c.ink),
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            AtmosphereCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Device name
                  ListTile(
                    title: Text(
                      'Device name',
                      style: AtmosphereTextStyles.body(c.ink2),
                    ),
                    subtitle: _editingName
                        ? TextField(
                            controller: _nameController,
                            autofocus: true,
                            style: AtmosphereTextStyles.body(c.ink),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _saveName(),
                          )
                        : Text(
                            device.name,
                            style: AtmosphereTextStyles.body(c.ink),
                          ),
                    trailing: _editingName
                        ? IconButton(
                            icon: Icon(AppIcons.check, color: c.brand),
                            onPressed: _saveName,
                          )
                        : IconButton(
                            icon: Icon(AppIcons.edit, color: c.ink3),
                            onPressed: () {
                              setState(() {
                                _editingName = true;
                                _nameController.text = device.name;
                              });
                            },
                          ),
                  ),
                  Divider(height: 1, color: c.line),
                  // Device ID
                  ListTile(
                    title: Text(
                      'Device ID',
                      style: AtmosphereTextStyles.body(c.ink2),
                    ),
                    subtitle: Text(
                      device.id,
                      style: AtmosphereTextStyles.mono(c.ink),
                    ),
                    trailing: IconButton(
                      icon: Icon(LucideIcons.copy, color: c.ink3),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: device.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Device ID copied'),
                            backgroundColor: c.brand,
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(height: 1, color: c.line),
                  // Room
                  ListTile(
                    title: Text(
                      'Room',
                      style: AtmosphereTextStyles.body(c.ink2),
                    ),
                    subtitle: Text(
                      device.roomId != null
                          ? rooms
                                  .where((r) => r.id == device.roomId)
                                  .firstOrNull
                                  ?.name ??
                              'Unknown room'
                          : 'No room assigned',
                      style: AtmosphereTextStyles.body(c.ink),
                    ),
                    trailing: Icon(AppIcons.chev, color: c.ink3),
                    onTap: () => _showRoomPicker(context, device, rooms),
                  ),
                  Divider(height: 1, color: c.line),
                  // Firmware version
                  ListTile(
                    title: Text(
                      'Firmware version',
                      style: AtmosphereTextStyles.body(c.ink2),
                    ),
                    subtitle: Text(
                      device.firmwareVer ?? 'Unknown',
                      style: AtmosphereTextStyles.mono(c.ink),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          context.push('/devices/${widget.deviceId}/ota'),
                      child: Text(
                        'Check update',
                        style: AtmosphereTextStyles.body(c.brand),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space32),

            // Sensor calibration section
            Text(
              'Sensor calibration',
              style: AtmosphereTextStyles.h2(c.ink),
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            AtmosphereCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      'CO sensor',
                      style: AtmosphereTextStyles.body(c.ink),
                    ),
                    subtitle: Text(
                      'Last calibrated 14d ago',
                      style: AtmosphereTextStyles.caption(c.ink3),
                    ),
                    trailing: Icon(AppIcons.chev, color: c.ink3),
                    onTap: () => context
                        .push('/devices/${widget.deviceId}/calibrate/co'),
                  ),
                  Divider(height: 1, color: c.line),
                  ListTile(
                    title: Row(
                      children: [
                        Text(
                          'NO₂ sensor',
                          style: AtmosphereTextStyles.body(c.ink),
                        ),
                        const SizedBox(width: AtmosphereTokens.space8),
                        const AtmospherePill(
                          label: 'Never calibrated',
                          tone: PillTone.warn,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Calibration recommended',
                      style: AtmosphereTextStyles.caption(c.ink3),
                    ),
                    trailing: Icon(AppIcons.chev, color: c.ink3),
                    onTap: () => context
                        .push('/devices/${widget.deviceId}/calibrate/no2'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space32),

            // Danger zone section
            Text(
              'Danger zone',
              style: AtmosphereTextStyles.h2(c.danger),
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            AtmosphereCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Delete this device',
                    style: AtmosphereTextStyles.body(c.ink),
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    'This will remove the device from your home. You can re-add it later through provisioning.',
                    style: AtmosphereTextStyles.caption(c.ink3),
                  ),
                  const SizedBox(height: AtmosphereTokens.space16),
                  DangerButton(
                    label: 'Delete device',
                    onPressed: () => _confirmDelete(context, device),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _editingName = false);

    final c = context.colors;

    try {
      await ref.read(deviceServiceProvider).updateDevice(
            widget.deviceId,
            name: newName,
          );
      ref.invalidate(devicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Device name updated'),
            backgroundColor: c.brand,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update name: $e'),
            backgroundColor: c.danger,
          ),
        );
      }
    }
  }

  void _showRoomPicker(BuildContext context, Device device, List<Room> rooms) {
    final c = context.colors;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'No room',
                style: AtmosphereTextStyles.body(c.ink),
              ),
              trailing: device.roomId == null
                  ? Icon(AppIcons.check, color: c.brand)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _updateRoom(device, null);
              },
            ),
            ...rooms.map((room) => ListTile(
                  title: Text(
                    room.name,
                    style: AtmosphereTextStyles.body(c.ink),
                  ),
                  trailing: device.roomId == room.id
                      ? Icon(AppIcons.check, color: c.brand)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _updateRoom(device, room.id);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRoom(Device device, String? roomId) async {
    final c = context.colors;

    try {
      await ref.read(deviceServiceProvider).updateDevice(
            widget.deviceId,
            roomId: roomId,
          );
      ref.invalidate(devicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Room updated'),
            backgroundColor: c.brand,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update room: $e'),
            backgroundColor: c.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Device device) async {
    final c = context.colors;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete device?'),
        content: Text(
          'This will permanently remove "${device.name}" from your home. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: c.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(devicesProvider.notifier).delete(device.id);
      if (mounted) {
        router.go('/home');
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Device deleted'),
            backgroundColor: c.brand,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete device: $e'),
            backgroundColor: c.danger,
          ),
        );
      }
    }
  }
}
