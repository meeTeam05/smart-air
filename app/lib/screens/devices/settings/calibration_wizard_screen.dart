import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app_theme.dart';
import '../../../core/back_navigation.dart';
import '../../../services/device_service.dart';
import '../../../widgets/shell/atmosphere_app_bar.dart';
import '../../../widgets/atoms/step_dots.dart';
import '../../../widgets/atoms/primary_button.dart';
import '../../../widgets/atoms/card.dart';

class CalibrationWizardScreen extends ConsumerStatefulWidget {
  const CalibrationWizardScreen({
    super.key,
    required this.deviceId,
    required this.sensor,
  });
  final String deviceId;
  final String sensor; // 'co' or 'no2'

  @override
  ConsumerState<CalibrationWizardScreen> createState() =>
      _CalibrationWizardScreenState();
}

class _CalibrationWizardScreenState
    extends ConsumerState<CalibrationWizardScreen> {
  int _currentStep = 0;
  bool _calibrating = false;
  String? _result;
  String? _error;
  int _elapsedSeconds = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final sensorLabel = widget.sensor.toUpperCase();

    return BackNavigationScope(
      fallbackRoute: '/devices/${widget.deviceId}/settings',
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AtmosphereAppBar.back(
          title: 'Calibrate $sensorLabel sensor',
          onBack: () => handleBackOrFallback(
            context,
            '/devices/${widget.deviceId}/settings',
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: AtmosphereTokens.space24),
            StepDots(current: _currentStep, total: 3),
            const SizedBox(height: AtmosphereTokens.space32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AtmosphereTokens.space20),
                child: _buildStepContent(c, sensorLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(AtmospherePalette c, String sensorLabel) {
    switch (_currentStep) {
      case 0:
        return _buildInstructionsStep(c, sensorLabel);
      case 1:
        return _buildCalibrationStep(c, sensorLabel);
      case 2:
        return _buildResultStep(c, sensorLabel);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInstructionsStep(AtmospherePalette c, String sensorLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Preparation',
          style: AtmosphereTextStyles.h1(c.ink),
        ),
        const SizedBox(height: AtmosphereTokens.space16),
        AtmosphereCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before calibrating the $sensorLabel sensor, ensure:',
                style: AtmosphereTextStyles.body(c.ink),
              ),
              const SizedBox(height: AtmosphereTokens.space16),
              _buildInstructionItem(
                c,
                '1',
                'Place the device outdoors in clean, fresh air',
              ),
              const SizedBox(height: AtmosphereTokens.space12),
              _buildInstructionItem(
                c,
                '2',
                'Keep it powered on for at least 24 hours (preheat period)',
              ),
              const SizedBox(height: AtmosphereTokens.space12),
              _buildInstructionItem(
                c,
                '3',
                'Avoid areas with traffic, smoke, or industrial emissions',
              ),
              const SizedBox(height: AtmosphereTokens.space12),
              _buildInstructionItem(
                c,
                '4',
                'Ensure stable temperature (15-25°C recommended)',
              ),
            ],
          ),
        ),
        const SizedBox(height: AtmosphereTokens.space24),
        AtmosphereCard(
          child: Row(
            children: [
              Icon(AppIcons.info, color: c.accent, size: 20),
              const SizedBox(width: AtmosphereTokens.space12),
              Expanded(
                child: Text(
                  'Calibration takes approximately 2-3 minutes. Do not move the device during this process.',
                  style: AtmosphereTextStyles.caption(c.ink2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AtmosphereTokens.space32),
        PrimaryButton(
          label: 'Start calibration',
          icon: LucideIcons.play,
          onPressed: () => setState(() => _currentStep = 1),
        ),
      ],
    );
  }

  Widget _buildInstructionItem(
      AtmospherePalette c, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c.brandTint,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AtmosphereTextStyles.caption(c.brand),
            ),
          ),
        ),
        const SizedBox(width: AtmosphereTokens.space12),
        Expanded(
          child: Text(
            text,
            style: AtmosphereTextStyles.body(c.ink2),
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationStep(AtmospherePalette c, String sensorLabel) {
    if (!_calibrating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ready to calibrate',
            style: AtmosphereTextStyles.h1(c.ink),
          ),
          const SizedBox(height: AtmosphereTokens.space16),
          AtmosphereCard(
            child: Column(
              children: [
                Icon(AppIcons.cog, size: 64, color: c.brand),
                const SizedBox(height: AtmosphereTokens.space16),
                Text(
                  'Press the button below to start the $sensorLabel sensor calibration process.',
                  style: AtmosphereTextStyles.body(c.ink2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AtmosphereTokens.space32),
          PrimaryButton(
            label: 'Start',
            icon: LucideIcons.play,
            onPressed: _startCalibration,
          ),
          const SizedBox(height: AtmosphereTokens.space12),
          TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: Text(
              'Back',
              style: AtmosphereTextStyles.body(c.ink3),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Calibrating...',
          style: AtmosphereTextStyles.h1(c.ink),
        ),
        const SizedBox(height: AtmosphereTokens.space16),
        AtmosphereCard(
          child: Column(
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: AtmosphereTokens.space24),
              Text(
                'Calibration in progress',
                style: AtmosphereTextStyles.h2(c.ink),
              ),
              const SizedBox(height: AtmosphereTokens.space8),
              Text(
                'Elapsed: ${_elapsedSeconds}s',
                style: AtmosphereTextStyles.mono(c.ink3),
              ),
              const SizedBox(height: AtmosphereTokens.space16),
              Text(
                'Please wait while the sensor calibrates. This may take 2-3 minutes.',
                style: AtmosphereTextStyles.caption(c.ink2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AtmosphereTokens.space24),
        AtmosphereCard(
          child: Row(
            children: [
              Icon(AppIcons.warn, color: c.warn, size: 20),
              const SizedBox(width: AtmosphereTokens.space12),
              Expanded(
                child: Text(
                  'Do not close the app or move the device',
                  style: AtmosphereTextStyles.caption(c.ink2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultStep(AtmospherePalette c, String sensorLabel) {
    final hasError = _error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasError ? 'Calibration failed' : 'Calibration complete',
          style: AtmosphereTextStyles.h1(c.ink),
        ),
        const SizedBox(height: AtmosphereTokens.space16),
        AtmosphereCard(
          child: Column(
            children: [
              Icon(
                hasError ? AppIcons.warn : AppIcons.check,
                size: 64,
                color: hasError ? c.danger : c.brand,
              ),
              const SizedBox(height: AtmosphereTokens.space16),
              if (hasError) ...[
                Text(
                  'Calibration error',
                  style: AtmosphereTextStyles.h2(c.danger),
                ),
                const SizedBox(height: AtmosphereTokens.space8),
                Text(
                  _error!,
                  style: AtmosphereTextStyles.body(c.ink2),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'Success',
                  style: AtmosphereTextStyles.h2(c.brand),
                ),
                const SizedBox(height: AtmosphereTokens.space8),
                if (_result != null)
                  Text(
                    _result!,
                    style: AtmosphereTextStyles.mono(c.ink),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: AtmosphereTokens.space8),
                Text(
                  'The $sensorLabel sensor has been successfully calibrated.',
                  style: AtmosphereTextStyles.body(c.ink2),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AtmosphereTokens.space32),
        if (hasError)
          PrimaryButton(
            label: 'Retry',
            icon: AppIcons.refresh,
            onPressed: () => setState(() {
              _currentStep = 1;
              _calibrating = false;
              _error = null;
              _result = null;
              _elapsedSeconds = 0;
            }),
          )
        else
          PrimaryButton(
            label: 'Done',
            icon: AppIcons.check,
            onPressed: () => context.pop(),
          ),
      ],
    );
  }

  void _startCalibration() async {
    setState(() {
      _calibrating = true;
      _elapsedSeconds = 0;
      _error = null;
      _result = null;
    });

    // Start elapsed timer
    final stopwatch = Stopwatch()..start();
    final timer = Stream.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _calibrating) {
        setState(() => _elapsedSeconds = stopwatch.elapsed.inSeconds);
      }
    }).listen((_) {});

    try {
      final commandType =
          widget.sensor == 'co' ? 'calibrate_co' : 'calibrate_no2';
      final commandId = await ref.read(deviceServiceProvider).sendCommand(
        widget.deviceId,
        {'type': commandType},
      );
      final command =
          await ref.read(deviceServiceProvider).waitForCommandCompletion(
                widget.deviceId,
                commandId,
              );

      if (mounted) {
        setState(() {
          _calibrating = false;
          _currentStep = 2;
          if (command.status == 'done') {
            _result =
                'Calibration command completed. Recheck live sensor values after the device settles.';
          } else {
            _error = 'Calibration finished with status: ${command.status}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calibrating = false;
          _currentStep = 2;
          _error = e.toString();
        });
      }
    } finally {
      timer.cancel();
      stopwatch.stop();
    }
  }
}
