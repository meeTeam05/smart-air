@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:smart_air/app_theme.dart';
import 'package:smart_air/design/tokens.dart';
import 'package:smart_air/widgets/atoms/atmosphere_switch.dart';
import 'package:smart_air/widgets/atoms/card.dart';
import 'package:smart_air/widgets/atoms/danger_button.dart';
import 'package:smart_air/widgets/atoms/dot_logo.dart';
import 'package:smart_air/widgets/atoms/empty_state.dart';
import 'package:smart_air/widgets/atoms/field.dart';
import 'package:smart_air/widgets/atoms/filter_chip.dart';
import 'package:smart_air/widgets/atoms/ghost_button.dart';
import 'package:smart_air/widgets/atoms/history_row.dart';
import 'package:smart_air/widgets/atoms/mode_card.dart';
import 'package:smart_air/widgets/atoms/pill.dart';
import 'package:smart_air/widgets/atoms/primary_button.dart';
import 'package:smart_air/widgets/atoms/relay_card.dart';
import 'package:smart_air/widgets/atoms/sensor_tile.dart';
import 'package:smart_air/widgets/atoms/step_dots.dart';
import 'package:smart_air/widgets/atoms/text_button_link.dart';

// Custom pump that avoids pumpAndSettle timeout for widgets with
// continuous animations (CircularProgressIndicator, etc.).
Future<void> _pumpOnce(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 300));

void main() {
  const runGoldens = bool.fromEnvironment('RUN_GOLDENS', defaultValue: false);

  group('Atmosphere Atoms Golden Baseline', () {
    testGoldens('Buttons - light theme', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: 'Primary', onPressed: () {}),
            const SizedBox(height: 16),
            // loading: true shows CircularProgressIndicator — use customPump
            PrimaryButton(label: 'Loading', onPressed: () {}, loading: true),
            const SizedBox(height: 16),
            GhostButton(label: 'Ghost', onPressed: () {}),
            const SizedBox(height: 16),
            TextLinkButton(label: 'Text Link', onPressed: () {}),
            const SizedBox(height: 16),
            DangerButton(label: 'Danger', onPressed: () {}),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(300, 400),
      );

      // Use customPump to avoid pumpAndSettle timeout from CircularProgressIndicator
      await screenMatchesGolden(
        tester,
        'atoms_buttons_light',
        customPump: _pumpOnce,
      );
    });

    testGoldens('Buttons - dark theme', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: 'Primary', onPressed: () {}),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Loading', onPressed: () {}, loading: true),
            const SizedBox(height: 16),
            GhostButton(label: 'Ghost', onPressed: () {}),
            const SizedBox(height: 16),
            TextLinkButton(label: 'Text Link', onPressed: () {}),
            const SizedBox(height: 16),
            DangerButton(label: 'Danger', onPressed: () {}),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.dark()),
        surfaceSize: const Size(300, 400),
      );

      await screenMatchesGolden(
        tester,
        'atoms_buttons_dark',
        customPump: _pumpOnce,
      );
    });

    testGoldens('Pills - all tones', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            AtmospherePill(label: 'Online', tone: PillTone.online),
            AtmospherePill(label: 'Offline', tone: PillTone.offline),
            AtmospherePill(label: 'Warning', tone: PillTone.warn),
            AtmospherePill(label: 'Brand', tone: PillTone.brand),
            AtmospherePill(label: 'Accent', tone: PillTone.accent),
            AtmospherePill(label: 'Danger', tone: PillTone.danger),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(400, 200),
      );

      await screenMatchesGolden(tester, 'atoms_pills_light');
    });

    testGoldens('Cards', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AtmosphereCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Basic Card', style: TextStyle(color: AtmosphereTokens.ink)),
              ),
            ),
            const SizedBox(height: 16),
            AtmosphereCard(
              gradient: LinearGradient(
                colors: [AtmosphereTokens.brand, AtmosphereTokens.brandTint],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Gradient Card', style: TextStyle(color: AtmosphereTokens.paper)),
              ),
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(300, 250),
      );

      await screenMatchesGolden(tester, 'atoms_cards_light');
    });

    testGoldens('Sensor Tiles - all tones', (tester) async {
      if (!runGoldens) return;
      // SensorTile uses Spacer() and needs bounded height.
      // Use a single-column layout so each tile gets full surface width —
      // avoids the 2-column constraint causing baseline-alignment overflow.
      await tester.pumpWidgetBuilder(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 150,
              child: SensorTile(
                label: 'Temperature',
                value: '24.5',
                unit: '°C',
                icon: Icons.thermostat,
                tone: SensorTone.warm,
                sparkColor: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: SensorTile(
                label: 'Humidity',
                value: '65',
                unit: '%',
                icon: Icons.water_drop,
                tone: SensorTone.air,
                sparkColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: SensorTile(
                label: 'CO',
                value: '0.8',
                unit: 'ppm',
                icon: Icons.air,
                tone: SensorTone.cool,
                sparkColor: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: SensorTile(
                label: 'NO₂',
                value: '0.05',
                unit: 'ppm',
                icon: Icons.cloud,
                tone: SensorTone.no2,
                sparkColor: Colors.purple,
              ),
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        // Single column: 350w × (4×150 + 3×8) = 350×624
        surfaceSize: const Size(350, 640),
      );

      // SensorTile has a TweenAnimationBuilder — use customPump to avoid timeout
      await screenMatchesGolden(
        tester,
        'atoms_sensor_tiles_light',
        customPump: _pumpOnce,
      );
    });

    testGoldens('Relay Cards', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        // Each RelayCard ~= 16pad + label + 8 + name + 12 + switch(48) + 8 + caption + 16pad ≈ 166px
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RelayCard(
              channel: 1,
              name: 'Fan',
              on: true,
              onTap: () {},
            ),
            const SizedBox(width: 12),
            RelayCard(
              channel: 2,
              name: 'Lamp',
              on: false,
              onTap: () {},
            ),
            const SizedBox(width: 12),
            RelayCard(
              channel: 3,
              name: 'Filter',
              on: false,
              disabled: true,
              onTap: () {},
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        // Increased height from 150 to 200 to accommodate relay card content
        surfaceSize: const Size(400, 200),
      );

      await screenMatchesGolden(tester, 'atoms_relay_cards_light');
    });

    testGoldens('Mode Card', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DeviceModeCard(
              mode: 'on',
              online: true,
              onChanged: (val) {},
            ),
            const SizedBox(height: 16),
            DeviceModeCard(
              mode: 'standby',
              online: true,
              onChanged: (val) {},
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        // Increased height from 300 to 420 (2 mode cards + 16 gap + margins)
        surfaceSize: const Size(350, 420),
      );

      // DeviceModeCard may have AtmosphereSwitch animation — use customPump
      await screenMatchesGolden(
        tester,
        'atoms_mode_card_light',
        customPump: _pumpOnce,
      );
    });

    testGoldens('Form Elements', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AtmosphereField(
              label: 'Email',
              controller: TextEditingController(text: 'you@example.com'),
            ),
            const SizedBox(height: 16),
            const AtmosphereField(
              label: 'Password',
              obscure: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Enable notifications'),
                const SizedBox(width: 16),
                AtmosphereSwitch(
                  value: true,
                  onChanged: (val) {},
                ),
              ],
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(350, 300),
      );

      await screenMatchesGolden(tester, 'atoms_form_elements_light');
    });

    testGoldens('History Row', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            HistoryRow(
              icon: Icons.power_settings_new,
              label: 'Mode changed to ON',
              sub: '2 minutes ago',
            ),
            HistoryRow(
              icon: Icons.wind_power,
              label: 'Fan turned ON',
              sub: '5 minutes ago',
              badgeTone: PillTone.online,
              badgeLabel: 'Done',
            ),
            HistoryRow(
              icon: Icons.settings,
              label: 'Calibration started',
              sub: '10 minutes ago',
              badgeTone: PillTone.accent,
              badgeLabel: 'Pending',
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(400, 250),
      );

      await screenMatchesGolden(tester, 'atoms_history_row_light');
    });

    testGoldens('Filter Chips', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Wrap(
          spacing: 8,
          children: [
            AtmosphereFilterChip(
              label: 'All',
              active: true,
              onTap: () {},
            ),
            AtmosphereFilterChip(
              label: 'Active',
              active: false,
              onTap: () {},
            ),
            AtmosphereFilterChip(
              label: 'Offline',
              active: false,
              onTap: () {},
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(300, 100),
      );

      await screenMatchesGolden(tester, 'atoms_filter_chips_light');
    });

    testGoldens('Step Dots', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StepDots(current: 0, total: 5),
            SizedBox(height: 16),
            StepDots(current: 2, total: 5),
            SizedBox(height: 16),
            StepDots(current: 4, total: 5),
          ],
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(200, 150),
      );

      await screenMatchesGolden(tester, 'atoms_step_dots_light');
    });

    testGoldens('Empty State', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        EmptyState(
          icon: Icons.inbox_outlined,
          title: 'No devices yet',
          body: 'Add your first device to get started',
          primaryAction: 'Add Device',
          onPrimaryAction: () {},
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        // Increased height from 300 to 460 (overflowed by 141px at 300)
        surfaceSize: const Size(350, 460),
      );

      await screenMatchesGolden(tester, 'atoms_empty_state_light');
    });

    testGoldens('Dot Logo', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        Center(
          child: AtmosphereDotLogo(size: 80, color: AtmosphereTokens.brand),
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(200, 200),
      );

      await screenMatchesGolden(tester, 'atoms_dot_logo_light');
    });
  });
}
