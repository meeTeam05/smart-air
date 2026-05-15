import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_exception.dart';
import '../../design/icons.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../services/ble_service.dart';
import '../../services/device_service.dart';
import '../../widgets/atoms/card.dart';
import '../../widgets/atoms/field.dart';
import '../../widgets/shell/ble_step_shell.dart';

class Step3WifiScreen extends ConsumerStatefulWidget {
  const Step3WifiScreen({
    super.key,
    required this.homeId,
    required this.mac,
    required this.deviceId,
    this.ssid,
  });

  final String homeId;
  final String mac;
  final String deviceId;
  final String? ssid;

  @override
  ConsumerState<Step3WifiScreen> createState() => _Step3WifiScreenState();
}

class _Step3WifiScreenState extends ConsumerState<Step3WifiScreen> {
  final BleService _ble = BleService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _ssidCtrl;
  late final TextEditingController _passCtrl;

  bool _obscure = true;
  bool _sending = false;
  String? _registeredDeviceId;
  String? _registeredSecretKey;

  String _defaultProvisioningName(String deviceId) {
    final suffix =
        deviceId.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
    if (suffix.isEmpty) {
      final fallbackLength = deviceId.length < 6 ? deviceId.length : 6;
      return 'Smart Air ${deviceId.substring(deviceId.length - fallbackLength).toUpperCase()}';
    }
    final displayLength = suffix.length < 6 ? suffix.length : 6;
    return 'Smart Air ${suffix.substring(suffix.length - displayLength)}';
  }

  @override
  void initState() {
    super.initState();
    _ssidCtrl = TextEditingController(text: widget.ssid ?? '');
    _passCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _ble.disconnect();
    super.dispose();
  }

  Future<void> _sendCredentials() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _sending) return;

    setState(() => _sending = true);

    try {
      if (widget.homeId.isEmpty) {
        throw StateError('Select a home before provisioning.');
      }

      final result =
          await _ble.sendCredentials(_ssidCtrl.text.trim(), _passCtrl.text);
      final deviceService = ref.read(deviceServiceProvider);
      String? secretKey;

      try {
        final registration = await deviceService.provisionDevice(
          deviceId: result.deviceId,
          name: _defaultProvisioningName(result.deviceId),
          homeId: widget.homeId,
        );
        _registeredDeviceId = registration.device.id;
        _registeredSecretKey = registration.secretKey;
        secretKey = registration.secretKey;
      } on ApiException catch (e) {
        if (e.statusCode != 409 || e.message != 'Device already registered') {
          rethrow;
        }

        if (_registeredDeviceId == result.deviceId &&
            _registeredSecretKey != null &&
            _registeredSecretKey!.isNotEmpty) {
          secretKey = _registeredSecretKey!;
        } else {
          final announced = await deviceService.checkAnnounce(result.deviceId);
          if (!announced) {
            throw const ApiException(
              409,
              'Device already registered and MQTT credentials cannot be recovered. Delete or factory reset the device, then provision again.',
            );
          }
        }
      }

      if (secretKey != null) {
        await deviceService.configureProvisionedDevice(
          host: result.ip,
          deviceId: result.deviceId,
          secretKey: secretKey,
        );
      }
      await _ble.disconnect();

      if (!mounted) return;
      context.push(
        '/provision/announce?homeId=${Uri.encodeComponent(widget.homeId)}&mac=${Uri.encodeComponent(widget.mac)}&deviceId=${Uri.encodeComponent(result.deviceId)}',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return BleStepShell(
      currentStep: 2,
      title: 'Connect to Wi‑Fi',
      subtitle:
          'Send Wi-Fi details, register the device with the server, then deliver its MQTT credentials locally.',
      body: Column(
        children: [
          AtmosphereCard(
            padding: const EdgeInsets.all(AtmosphereTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.accentTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(AppIcons.wifi, color: c.accent),
                    ),
                    const SizedBox(width: AtmosphereTokens.space12),
                    Expanded(
                      child: Text(
                        widget.mac,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AtmosphereTokens.space20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AtmosphereField(
                        label: 'Wi‑Fi network',
                        controller: _ssidCtrl,
                        prefixIcon: AppIcons.wifi,
                        keyboardType: TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your Wi‑Fi SSID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AtmosphereTokens.space16),
                      AtmosphereField(
                        label: 'Password',
                        controller: _passCtrl,
                        prefixIcon: AppIcons.lock,
                        obscure: _obscure,
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? AppIcons.eyeOff : AppIcons.eye),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AtmosphereTokens.space16),
          Text(
            'We keep the BLE link open just long enough to deliver the credentials securely.',
            style: TextStyle(color: c.ink2, fontSize: 13, height: 1.45),
          ),
        ],
      ),
      primaryLabel: _sending ? 'Sending…' : 'Send credentials',
      primaryLoading: _sending,
      primaryEnabled: !_sending,
      onPrimary: _sendCredentials,
      secondaryLabel: 'Back',
      onSecondary: () => context.pop(),
      onCancel: () => context.pop(),
    );
  }
}
