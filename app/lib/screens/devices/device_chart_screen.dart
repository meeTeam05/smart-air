import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../providers/devices_provider.dart';
import '../../widgets/async_value_widget.dart';

class DeviceChartScreen extends ConsumerStatefulWidget {
  const DeviceChartScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<DeviceChartScreen> createState() => _DeviceChartScreenState();
}

class _DeviceChartScreenState extends ConsumerState<DeviceChartScreen> {
  int _rangeIndex = 1; // 0=1h, 1=24h, 2=7d

  static const _ranges = ['1h', '24h', '7d'];

  TelemetryParams _params() {
    final now = DateTime.now();
    final from = switch (_rangeIndex) {
      0 => now.subtract(const Duration(hours: 1)),
      1 => now.subtract(const Duration(hours: 24)),
      _ => now.subtract(const Duration(days: 7)),
    };
    final agg = switch (_rangeIndex) {
      0 => '1m',
      1 => '15m',
      _ => '1h',
    };
    return TelemetryParams(
      deviceId: widget.deviceId,
      from: from,
      to: now,
      agg: agg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final params = _params();
    final telemetry = ref.watch(telemetryProvider(params));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('Chart', style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: List.generate(
              3,
              (i) => ButtonSegment(value: i, label: Text(_ranges[i])),
            ),
            selected: {_rangeIndex},
            onSelectionChanged: (s) => setState(() => _rangeIndex = s.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AsyncValueWidget(
                value: telemetry,
                data: (points) {
                  if (points.isEmpty) {
                    return Center(
                      child: Text(
                        'No data for this range',
                        style: TextStyle(color: c.textSecondary),
                      ),
                    );
                  }

                  final minTs = points.first.ts.millisecondsSinceEpoch.toDouble();
                  final maxTs = points.last.ts.millisecondsSinceEpoch.toDouble();
                  final temps = points.map((p) => p.temperature);
                  final hums = points.map((p) => p.humidity);
                  final minY = (temps.reduce((a, b) => a < b ? a : b))
                      .clamp(0, 50)
                      .toDouble() - 5;
                  final maxY = (hums.reduce((a, b) => a > b ? a : b))
                      .clamp(0, 100)
                      .toDouble() + 5;

                  return LineChart(
                    LineChartData(
                      minX: minTs,
                      maxX: maxTs,
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: c.border,
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (_) => FlLine(
                          color: c.border,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(
                        border: Border.all(color: c.border),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(0),
                              style: TextStyle(
                                  fontSize: 10, color: c.textSecondary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: (maxTs - minTs) / 4,
                            getTitlesWidget: (v, _) {
                              final dt = DateTime.fromMillisecondsSinceEpoch(
                                  v.toInt());
                              final label = _rangeIndex == 2
                                  ? '${dt.month}/${dt.day}'
                                  : '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                              return Text(
                                label,
                                style: TextStyle(
                                    fontSize: 9, color: c.textSecondary),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        // Temperature
                        LineChartBarData(
                          spots: points
                              .map((p) => FlSpot(
                                    p.ts.millisecondsSinceEpoch.toDouble(),
                                    p.temperature,
                                  ))
                              .toList(),
                          isCurved: true,
                          color: AppColors.warning,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.warning.withValues(alpha: 0.1),
                          ),
                        ),
                        // Humidity
                        LineChartBarData(
                          spots: points
                              .map((p) => FlSpot(
                                    p.ts.millisecondsSinceEpoch.toDouble(),
                                    p.humidity,
                                  ))
                              .toList(),
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Legend(color: AppColors.warning, label: 'Temperature (°C)'),
                SizedBox(width: 24),
                _Legend(color: AppColors.primary, label: 'Humidity (%)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ],
    );
  }
}
