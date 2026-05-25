import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/icons.dart';
import '../../design/palette.dart';
import '../../design/text_styles.dart';
import '../../design/tokens.dart';
import '../../models/home.dart';
import '../../providers/devices_provider.dart';
import '../../providers/homes_provider.dart';
import '../../services/device_service.dart';
import '../../widgets/atoms/card.dart';
import '../../widgets/atoms/field.dart';
import '../../widgets/shell/ble_step_shell.dart';

class Step5NameScreen extends ConsumerStatefulWidget {
  const Step5NameScreen({
    super.key,
    required this.homeId,
    required this.mac,
    required this.deviceId,
  });

  final String homeId;
  final String mac;
  final String deviceId;

  @override
  ConsumerState<Step5NameScreen> createState() => _Step5NameScreenState();
}

class _Step5NameScreenState extends ConsumerState<Step5NameScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  String? _selectedRoomId;
  bool _saving = false;

  bool get _hasRequiredRouteState =>
      widget.homeId.isNotEmpty && widget.deviceId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.deviceId.isEmpty) {
      _nameCtrl = TextEditingController(text: 'Smart Air');
      return;
    }
    final suffix =
        widget.deviceId.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
    final displaySuffix = suffix.isEmpty
        ? widget.deviceId
            .substring(widget.deviceId.length -
                (widget.deviceId.length < 6 ? widget.deviceId.length : 6))
            .toUpperCase()
        : suffix
            .substring(suffix.length - (suffix.length < 6 ? suffix.length : 6));
    _nameCtrl = TextEditingController(text: 'Smart Air $displaySuffix');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _saving) return;

    setState(() => _saving = true);

    try {
      await ref.read(deviceServiceProvider).updateDevice(
            widget.deviceId,
            name: _nameCtrl.text.trim(),
            roomId: _selectedRoomId,
          );
      ref.invalidate(devicesProvider);

      if (!mounted) return;
      context.go('/devices/${widget.deviceId}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (!_hasRequiredRouteState) {
      return BleStepShell(
        currentStep: 4,
        title: 'Name your device',
        subtitle:
            'Provisioning link is incomplete. Start again before naming device.',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AtmosphereCard(
              padding: const EdgeInsets.all(AtmosphereTokens.space16),
              child: Column(
                children: [
                  Icon(AppIcons.warn, color: c.danger, size: 30),
                  const SizedBox(height: AtmosphereTokens.space16),
                  Text(
                    'Missing provisioning details',
                    style: AtmosphereTextStyles.h2(c.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    'This step needs both a home and device ID. Start provisioning again.',
                    style: AtmosphereTextStyles.body(c.ink2),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        primaryLabel: 'Start over',
        onPrimary: () => context.go('/home'),
        secondaryLabel: 'Cancel',
        onSecondary: () => context.go('/home'),
        onCancel: () => context.go('/home'),
      );
    }

    final homesAsync = ref.watch(homesProvider);
    final roomsAsync = widget.homeId.isNotEmpty
        ? ref.watch(roomsProvider(widget.homeId))
        : null;

    final homes = homesAsync.valueOrNull ?? const <Home>[];
    final selectedHome = widget.homeId.isNotEmpty
        ? homes.firstWhere(
            (home) => home.id == widget.homeId,
            orElse: () => const Home(id: '', name: ''),
          )
        : null;
    final roomList = roomsAsync?.valueOrNull ?? const <Room>[];

    return BleStepShell(
      currentStep: 4,
      title: 'Name your device',
      subtitle:
          'Confirm the final label and room before opening the dashboard.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AtmosphereCard(
            padding: const EdgeInsets.all(AtmosphereTokens.space16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AtmosphereField(
                    label: 'Device name',
                    controller: _nameCtrl,
                    prefixIcon: AppIcons.edit,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a device name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AtmosphereTokens.space16),
                  Text(
                    'Home',
                    style: AtmosphereTextStyles.body(c.ink),
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  _ReadonlyValueCard(
                    value: selectedHome?.name.isNotEmpty == true
                        ? selectedHome!.name
                        : homesAsync.isLoading
                            ? 'Loading home…'
                            : 'Unknown home',
                  ),
                  if (selectedHome != null && selectedHome.id.isNotEmpty) ...[
                    const SizedBox(height: AtmosphereTokens.space16),
                    Text(
                      'Room',
                      style: AtmosphereTextStyles.body(c.ink),
                    ),
                    const SizedBox(height: AtmosphereTokens.space8),
                    _DropdownCard<String?>(
                      value: _selectedRoomId,
                      hint: roomsAsync == null
                          ? 'Select a home first'
                          : roomsAsync.isLoading
                              ? 'Loading rooms…'
                              : roomList.isEmpty
                                  ? 'No room selected'
                                  : 'Optional',
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No room'),
                        ),
                        ...roomList.map(
                          (room) => DropdownMenuItem<String?>(
                            value: room.id,
                            child: Text(room.name),
                          ),
                        ),
                      ],
                      onChanged: roomsAsync == null
                          ? null
                          : (value) => setState(() => _selectedRoomId = value),
                    ),
                  ],
                  const SizedBox(height: AtmosphereTokens.space16),
                  Text(
                    'This is the label your household will see in the Home tab and dashboard.',
                    style: TextStyle(color: c.ink2, fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      primaryLabel: _saving ? 'Saving…' : 'Save',
      primaryLoading: _saving,
      primaryEnabled: !_saving,
      onPrimary: _save,
      secondaryLabel: 'Back',
      onSecondary: () => context.pop(),
      onCancel: () => context.pop(),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  const _DropdownCard({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
        border: Border.all(color: c.line, width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AtmosphereTokens.space12,
        vertical: 2,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          icon: Icon(AppIcons.chevDown, color: c.ink3),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ReadonlyValueCard extends StatelessWidget {
  const _ReadonlyValueCard({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
        border: Border.all(color: c.line, width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AtmosphereTokens.space12,
        vertical: AtmosphereTokens.space16,
      ),
      child: Text(
        value,
        style: AtmosphereTextStyles.body(c.ink),
      ),
    );
  }
}
