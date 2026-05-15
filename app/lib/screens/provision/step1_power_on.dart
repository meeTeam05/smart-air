import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/icons.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../widgets/atoms/card.dart';
import '../../widgets/shell/ble_step_shell.dart';

class Step1PowerOnScreen extends StatefulWidget {
  const Step1PowerOnScreen({super.key, required this.homeId});

  final String homeId;

  @override
  State<Step1PowerOnScreen> createState() => _Step1PowerOnScreenState();
}

class _Step1PowerOnScreenState extends State<Step1PowerOnScreen> {
  bool _pulseOn = true;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => _pulseOn = !_pulseOn);
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return BleStepShell(
      currentStep: 0,
      title: 'Power on your device',
      subtitle:
          'Press and hold BOOT for 3 seconds until the LED blinks, then continue.',
      body: Column(
        children: [
          AtmosphereCard(
            padding: const EdgeInsets.all(AtmosphereTokens.space24),
            child: Column(
              children: [
                Container(
                  width: 220,
                  height: 180,
                  decoration: BoxDecoration(
                    color: c.brandTint,
                    borderRadius:
                        BorderRadius.circular(AtmosphereTokens.radiusCard),
                    border: Border.all(color: c.line, width: 1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 122,
                        height: 104,
                        decoration: BoxDecoration(
                          color: c.paper,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: c.line, width: 1.2),
                          boxShadow: AtmosphereTokens.shadowCard,
                        ),
                        child: Icon(AppIcons.device, size: 54, color: c.brand),
                      ),
                      Positioned(
                        top: 34,
                        right: 38,
                        child: AnimatedOpacity(
                          opacity: _pulseOn ? 1 : 0.25,
                          duration: const Duration(milliseconds: 500),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: c.brand,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: c.brand.withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AtmosphereTokens.space12,
                            vertical: AtmosphereTokens.space6,
                          ),
                          decoration: BoxDecoration(
                            color: c.paper.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(
                                AtmosphereTokens.radiusPill),
                          ),
                          child: Text(
                            'LED blinking',
                            style: TextStyle(
                              color: c.brand,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AtmosphereTokens.space20),
                Text(
                  'Make sure the device is close by and ready to join your Wi‑Fi network.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.ink2,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      primaryLabel: 'Continue',
      onPrimary: () => context
          .push('/provision/scan?homeId=${Uri.encodeComponent(widget.homeId)}'),
      secondaryLabel: 'Cancel',
      onSecondary: () => context.go('/home'),
      onCancel: () => context.go('/home'),
    );
  }
}
