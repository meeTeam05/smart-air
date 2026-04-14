import 'package:flutter/material.dart';
import '../app_theme.dart';

// ── Data model ────────────────────────────────────────────────────────────────

enum AutomationType { time, sensor }

class _Automation {
  final AutomationType type;
  final String label;
  final String description;

  const _Automation({
    required this.type,
    required this.label,
    required this.description,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  final List<_Automation> _automations = [];

  AppPalette get c => context.colors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        titleSpacing: 16,
        title: Text(
          'Automation',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
        actions: [
          if (_automations.isNotEmpty)
            IconButton(
              icon: Icon(Icons.filter_list, color: c.textSecondary),
              onPressed: () {},
            ),
        ],
      ),
      body: _automations.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: _automations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AutomationTile(
                automation: _automations[i],
                onDelete: () => setState(() => _automations.removeAt(i)),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddAutomation(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddAutomation(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Add automation',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.timer, color: AppColors.primary),
                title: Text('By time',
                    style: TextStyle(color: c.textPrimary)),
                subtitle: Text('Runs automatically at a fixed time',
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: c.textSecondary),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showTimeForm(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sensors, color: AppColors.primary),
                title: Text('By sensor',
                    style: TextStyle(color: c.textPrimary)),
                subtitle: Text('Based on temperature, humidity, etc.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: c.textSecondary),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showSensorForm(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Time-based form ────────────────────────────────────────────────────────
  void _showTimeForm(BuildContext ctx) {
    TimeOfDay selectedTime = const TimeOfDay(hour: 7, minute: 0);
    bool mon = true,
        tue = true,
        wed = true,
        thu = true,
        fri = true,
        sat = false,
        sun = false;
    final labelCtrl = TextEditingController(text: 'Turn on purifier');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (formCtx) => StatefulBuilder(
        builder: (_, setLocal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(formCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.timer,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Schedule name',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary)),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: c.textSecondary),
                          onPressed: () => Navigator.pop(formCtx),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 0, color: c.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label
                        TextField(
                          controller: labelCtrl,
                          style: TextStyle(color: c.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Schedule name',
                            labelStyle: TextStyle(color: c.textSecondary),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: c.border)),
                            focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Time picker row
                        Row(
                          children: [
                            Text('Trigger time',
                                style: TextStyle(
                                    fontSize: 14, color: c.textPrimary)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: formCtx,
                                  initialTime: selectedTime,
                                  builder: (c, w) => Theme(
                                    data: ThemeData.dark(),
                                    child: w!,
                                  ),
                                );
                                if (t != null) setLocal(() => selectedTime = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.surfaceVar,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  selectedTime.format(ctx),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Day chips
                        Text('Repeat',
                            style:
                                TextStyle(fontSize: 14, color: c.textPrimary)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _DayChip(
                                'T2', mon, () => setLocal(() => mon = !mon)),
                            _DayChip(
                                'T3', tue, () => setLocal(() => tue = !tue)),
                            _DayChip(
                                'T4', wed, () => setLocal(() => wed = !wed)),
                            _DayChip(
                                'T5', thu, () => setLocal(() => thu = !thu)),
                            _DayChip(
                                'T6', fri, () => setLocal(() => fri = !fri)),
                            _DayChip(
                                'T7', sat, () => setLocal(() => sat = !sat)),
                            _DayChip(
                                'CN', sun, () => setLocal(() => sun = !sun)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              final label = labelCtrl.text.trim();
                              final days = [
                                if (mon) 'T2',
                                if (tue) 'T3',
                                if (wed) 'T4',
                                if (thu) 'T5',
                                if (fri) 'T6',
                                if (sat) 'T7',
                                if (sun) 'CN',
                              ];
                              Navigator.pop(formCtx);
                              if (label.isNotEmpty) {
                                setState(() => _automations.add(_Automation(
                                      type: AutomationType.time,
                                      label: label,
                                      description:
                                          '${selectedTime.format(ctx)} · ${days.join(', ')}',
                                    )));
                              }
                            },
                            child: const Text('Save schedule'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sensor-based form ──────────────────────────────────────────────────────
  void _showSensorForm(BuildContext ctx) {
    String selectedMetric = 'Temperature';
    String selectedOp = '>';
    final valueCtrl = TextEditingController(text: '30');
    final labelCtrl = TextEditingController(text: 'Auto cooling');

    const metrics = ['Temperature', 'Humidity', 'PM2.5', 'CO₂'];
    const ops = ['>', '<', '≥', '≤', '='];
    const units = {
      'Temperature': '°C',
      'Humidity': '%',
      'PM2.5': 'µg/m³',
      'CO₂': 'ppm',
    };

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (formCtx) => StatefulBuilder(
        builder: (_, setLocal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(formCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.sensors,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Sensor condition',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary)),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: c.textSecondary),
                          onPressed: () => Navigator.pop(formCtx),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 0, color: c.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label
                        TextField(
                          controller: labelCtrl,
                          style: TextStyle(color: c.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Condition name',
                            labelStyle: TextStyle(color: c.textSecondary),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: c.border)),
                            focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('When',
                            style: TextStyle(
                                fontSize: 13, color: c.textSecondary)),
                        const SizedBox(height: 8),
                        // Condition row
                        Row(
                          children: [
                            // Metric dropdown
                            Expanded(
                              flex: 3,
                              child: _DropdownField<String>(
                                value: selectedMetric,
                                items: metrics,
                                onChanged: (v) =>
                                    setLocal(() => selectedMetric = v!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Operator dropdown
                            _DropdownField<String>(
                              value: selectedOp,
                              items: ops,
                              onChanged: (v) => setLocal(() => selectedOp = v!),
                            ),
                            const SizedBox(width: 8),
                            // Value + unit
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: valueCtrl,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                          color: c.textPrimary, fontSize: 15),
                                      decoration: InputDecoration(
                                        suffixText: units[selectedMetric] ?? '',
                                        suffixStyle: TextStyle(
                                            color: c.textSecondary,
                                            fontSize: 12),
                                        enabledBorder: UnderlineInputBorder(
                                            borderSide:
                                                BorderSide(color: c.border)),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: AppColors.primary)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              final label = labelCtrl.text.trim();
                              final val = valueCtrl.text.trim();
                              final unit = units[selectedMetric] ?? '';
                              Navigator.pop(formCtx);
                              if (label.isNotEmpty) {
                                setState(() => _automations.add(_Automation(
                                      type: AutomationType.sensor,
                                      label: label,
                                      description:
                                          '$selectedMetric $selectedOp $val$unit',
                                    )));
                              }
                            },
                            child: const Text('Save condition'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Automation tile ───────────────────────────────────────────────────────────

class _AutomationTile extends StatelessWidget {
  final _Automation automation;
  final VoidCallback onDelete;

  const _AutomationTile({required this.automation, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isTime = automation.type == AutomationType.time;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isTime ? Icons.timer : Icons.sensors,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(automation.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(automation.description,
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              children: [
                Positioned(
                  left: 18,
                  top: 18,
                  child: Container(
                    width: 62,
                    height: 68,
                    decoration: BoxDecoration(
                      color: c.surfaceVar,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Container(
                  width: 62,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.format_list_bulleted,
                    color: c.textSecondary,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap + to add an automation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : c.surfaceVar,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  const _DropdownField(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceVar,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: c.surface,
          style: TextStyle(fontSize: 13, color: c.textPrimary),
          iconSize: 16,
          isDense: true,
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(e.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
