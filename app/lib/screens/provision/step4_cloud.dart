import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/icons.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../services/device_service.dart';
import '../../widgets/atoms/card.dart';
import '../../widgets/shell/ble_step_shell.dart';

class Step4CloudScreen extends ConsumerStatefulWidget {
  const Step4CloudScreen({
    super.key,
    required this.homeId,
    required this.mac,
    required this.deviceId,
  });

  final String homeId;
  final String mac;
  final String deviceId;

  @override
  ConsumerState<Step4CloudScreen> createState() => _Step4CloudScreenState();
}

class _Step4CloudScreenState extends ConsumerState<Step4CloudScreen> {
  Timer? _pollTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  bool _success = false;
  bool _polling = false;
  bool _pollRequestInFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _begin() {
    if (_polling) return;

    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _success = false;
      _error = null;
    });
    _polling = true;
    _pollRequestInFlight = false;

    final deviceService = ref.read(deviceServiceProvider);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    Object? lastError;

    Future<void> pollOnce() async {
      if (!_polling || _pollRequestInFlight) return;
      _pollRequestInFlight = true;
      try {
        final announced = await deviceService.checkAnnounce(widget.deviceId);
        if (!mounted || !_polling) return;
        if (announced) {
          _pollTimer?.cancel();
          _elapsedTimer?.cancel();
          _polling = false;
          setState(() {
            _success = true;
          });
          context.push(
            '/provision/name?homeId=${Uri.encodeComponent(widget.homeId)}&mac=${Uri.encodeComponent(widget.mac)}&deviceId=${Uri.encodeComponent(widget.deviceId)}',
          );
          return;
        }
        lastError = null;
      } catch (error) {
        lastError = error;
      } finally {
        _pollRequestInFlight = false;
      }

      if (!mounted || !_polling || DateTime.now().isBefore(deadline)) return;

      _pollTimer?.cancel();
      _elapsedTimer?.cancel();
      _polling = false;
      setState(() {
        _error = lastError == null
            ? 'Device did not announce within 60 seconds. Check Wi-Fi and try again.'
            : 'Device did not announce within 60 seconds. Last error: $lastError';
      });
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(pollOnce());
    });
    unawaited(pollOnce());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return BleStepShell(
      currentStep: 3,
      title: 'Confirm cloud connection',
      subtitle:
          'We’re waiting for the device to reboot, connect to MQTT, and announce itself to the cloud.',
      body: Column(
        children: [
          AtmosphereCard(
            padding: const EdgeInsets.all(AtmosphereTokens.space20),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.cloud, color: c.brand, size: 34),
                ),
                const SizedBox(height: AtmosphereTokens.space20),
                Text(
                  _error != null
                      ? 'Cloud check failed'
                      : _success
                          ? 'Device connected'
                          : 'Connecting to cloud…',
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AtmosphereTokens.space8),
                Text(
                  _error != null
                      ? _error!
                      : 'Elapsed ${_elapsedSeconds}s · checking every 2 seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.ink2, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: AtmosphereTokens.space20),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: _error == null
                      ? const CircularProgressIndicator(strokeWidth: 3)
                      : Icon(AppIcons.warn, color: c.danger, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
      primaryLabel: _error == null ? 'Waiting…' : 'Retry',
      primaryEnabled: _error != null,
      onPrimary: _begin,
      secondaryLabel: 'Cancel',
      onSecondary: () => context.go('/home'),
      onCancel: () => context.go('/home'),
    );
  }
}
