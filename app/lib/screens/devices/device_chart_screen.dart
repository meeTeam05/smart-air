import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import '../../models/telemetry.dart';
import '../../providers/devices_provider.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/atoms/filter_chip.dart';
import '../../widgets/atoms/empty_state.dart';
import '../../widgets/shell/atmosphere_app_bar.dart';
import '../../design/icons.dart';

enum _Metric { temp, humidity, co, no2 }

class DeviceChartScreen extends ConsumerStatefulWidget {
  const DeviceChartScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<DeviceChartScreen> createState() => _DeviceChartScreenState();
}

class _DeviceChartScreenState extends ConsumerState<DeviceChartScreen> {
  final Set<_Metric> _activeMetrics = {_Metric.temp, _Metric.humidity};
  TelemetryHistoryRange _range = TelemetryHistoryRange.h24;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final telemetry = ref.watch(
      telemetryHistoryProvider(
        TelemetryHistoryParams(deviceId: widget.deviceId, range: _range),
      ),
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const AtmosphereAppBar.back(
        title: 'Charts',
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
                  label: 'Temp',
                  active: _activeMetrics.contains(_Metric.temp),
                  onTap: () => setState(() => _toggleMetric(_Metric.temp)),
                ),
                const SizedBox(width: AtmosphereTokens.space8),
                AtmosphereFilterChip(
                  label: 'Humidity',
                  active: _activeMetrics.contains(_Metric.humidity),
                  onTap: () => setState(() => _toggleMetric(_Metric.humidity)),
                ),
                const SizedBox(width: AtmosphereTokens.space8),
                AtmosphereFilterChip(
                  label: 'CO',
                  active: _activeMetrics.contains(_Metric.co),
                  onTap: () => setState(() => _toggleMetric(_Metric.co)),
                ),
                const SizedBox(width: AtmosphereTokens.space8),
                AtmosphereFilterChip(
                  label: 'NO₂',
                  active: _activeMetrics.contains(_Metric.no2),
                  onTap: () => setState(() => _toggleMetric(_Metric.no2)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AtmosphereTokens.space12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AtmosphereTokens.space16),
            child: Row(
              children: [
                AtmosphereFilterChip(
                  label: '1h',
                  active: _range == TelemetryHistoryRange.h1,
                  onTap: () => _setRange(TelemetryHistoryRange.h1),
                ),
                const SizedBox(width: AtmosphereTokens.space8),
                AtmosphereFilterChip(
                  label: '6h',
                  active: _range == TelemetryHistoryRange.h6,
                  onTap: () => _setRange(TelemetryHistoryRange.h6),
                ),
                const SizedBox(width: AtmosphereTokens.space8),
                AtmosphereFilterChip(
                  label: '24h',
                  active: _range == TelemetryHistoryRange.h24,
                  onTap: () => _setRange(TelemetryHistoryRange.h24),
                ),
                const SizedBox(width: AtmosphereTokens.space8),
                AtmosphereFilterChip(
                  label: '7d',
                  active: _range == TelemetryHistoryRange.d7,
                  onTap: () => _setRange(TelemetryHistoryRange.d7),
                ),
                const SizedBox(width: AtmosphereTokens.space8),
                AtmosphereFilterChip(
                  label: '30d',
                  active: _range == TelemetryHistoryRange.d30,
                  onTap: () => _setRange(TelemetryHistoryRange.d30),
                ),
              ],
            ),
          ),
          const SizedBox(height: AtmosphereTokens.space24),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AtmosphereTokens.space16),
              child: AsyncValueWidget(
                value: telemetry,
                data: (history) {
                  if (history.points.isEmpty || _activeMetrics.isEmpty) {
                    return const EmptyState(
                      icon: AppIcons.chart,
                      title: 'No data in this window',
                      body:
                          'Select metrics and a time range to view historical data.',
                    );
                  }

                  return _ChartWidget(
                    points: history.points,
                    activeMetrics: _activeMetrics,
                    from: history.from,
                    to: history.to,
                    xInterval: _range.xInterval,
                    range: _range,
                  );
                },
              ),
            ),
          ),
          _LegendRow(activeMetrics: _activeMetrics),
          const SizedBox(height: AtmosphereTokens.space16),
        ],
      ),
    );
  }

  void _toggleMetric(_Metric metric) {
    if (_activeMetrics.contains(metric)) {
      if (_activeMetrics.length > 1) {
        _activeMetrics.remove(metric);
      }
    } else {
      _activeMetrics.add(metric);
    }
  }

  void _setRange(TelemetryHistoryRange range) {
    setState(() {
      _range = range;
    });
  }
}

class _ChartWidget extends StatelessWidget {
  const _ChartWidget({
    required this.points,
    required this.activeMetrics,
    required this.from,
    required this.to,
    required this.xInterval,
    required this.range,
  });

  final List<TelemetryPoint> points;
  final Set<_Metric> activeMetrics;
  final DateTime from;
  final DateTime to;
  final double xInterval;
  final TelemetryHistoryRange range;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final minX = from.millisecondsSinceEpoch.toDouble();
    final maxX = to.millisecondsSinceEpoch.toDouble();

    final allValues = <double>[];
    for (final p in points) {
      if (activeMetrics.contains(_Metric.temp) && p.temperature != null) {
        allValues.add(p.temperature!);
      }
      if (activeMetrics.contains(_Metric.humidity) && p.humidity != null) {
        allValues.add(p.humidity!);
      }
      if (activeMetrics.contains(_Metric.co) && p.coPpm != null) {
        allValues.add(p.coPpm!);
      }
      if (activeMetrics.contains(_Metric.no2) && p.no2Ppm != null) {
        allValues.add(p.no2Ppm!);
      }
    }

    final minValue =
        allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final maxValue =
        allValues.isEmpty ? 100.0 : allValues.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs();
    final padding = span == 0 ? 1.0 : span * 0.1;
    final minY = (minValue - padding) < 0 ? 0.0 : minValue - padding;
    final maxY = maxValue + padding;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          getDrawingHorizontalLine: (_) => FlLine(
            color: c.line,
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: c.line,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          border: Border.all(color: c.line),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style:
                    AtmosphereTextStyles.caption(c.ink3).copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: xInterval,
              getTitlesWidget: (v, _) {
                final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt());
                final label = range == TelemetryHistoryRange.d7 ||
                        range == TelemetryHistoryRange.d30
                    ? '${dt.month}/${dt.day}'
                    : '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                return Text(
                  label,
                  style: AtmosphereTextStyles.caption(c.ink3)
                      .copyWith(fontSize: 9),
                );
              },
            ),
          ),
        ),
        lineBarsData: _buildLines(c),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.paper,
            getTooltipItems: (spots) => spots.map((spot) {
              final label = _metricLabel(spot.barIndex);
              return LineTooltipItem(
                '$label\n${spot.y.toStringAsFixed(1)}',
                AtmosphereTextStyles.caption(c.ink),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLines(AtmospherePalette c) {
    final lines = <LineChartBarData>[];

    if (activeMetrics.contains(_Metric.temp)) {
      lines.add(LineChartBarData(
        spots: points
            .map((point) {
              final value = point.temperature;
              if (value == null) return null;
              return FlSpot(
                point.ts.millisecondsSinceEpoch.toDouble(),
                value,
              );
            })
            .whereType<FlSpot>()
            .toList(),
        isCurved: true,
        color: c.danger,
        barWidth: 2,
        dotData: FlDotData(show: points.length <= 10),
        belowBarData: BarAreaData(
          show: true,
          color: c.danger.withValues(alpha: 0.1),
        ),
      ));
    }

    if (activeMetrics.contains(_Metric.humidity)) {
      lines.add(LineChartBarData(
        spots: points
            .map((point) {
              final value = point.humidity;
              if (value == null) return null;
              return FlSpot(
                point.ts.millisecondsSinceEpoch.toDouble(),
                value,
              );
            })
            .whereType<FlSpot>()
            .toList(),
        isCurved: true,
        color: c.accent,
        barWidth: 2,
        dotData: FlDotData(show: points.length <= 10),
        belowBarData: BarAreaData(
          show: true,
          color: c.accent.withValues(alpha: 0.1),
        ),
      ));
    }

    if (activeMetrics.contains(_Metric.co)) {
      lines.add(LineChartBarData(
        spots: points
            .map((point) {
              final value = point.coPpm;
              if (value == null) return null;
              return FlSpot(
                point.ts.millisecondsSinceEpoch.toDouble(),
                value,
              );
            })
            .whereType<FlSpot>()
            .toList(),
        isCurved: true,
        color: c.brand,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    if (activeMetrics.contains(_Metric.no2)) {
      lines.add(LineChartBarData(
        spots: points
            .map((point) {
              final value = point.no2Ppm;
              if (value == null) return null;
              return FlSpot(
                point.ts.millisecondsSinceEpoch.toDouble(),
                value,
              );
            })
            .whereType<FlSpot>()
            .toList(),
        isCurved: true,
        color: const Color(0xFF7A4FD0),
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    return lines;
  }

  String _metricLabel(int index) {
    final metrics = activeMetrics.toList();
    if (index >= metrics.length) return '';
    return switch (metrics[index]) {
      _Metric.temp => 'Temp',
      _Metric.humidity => 'Humidity',
      _Metric.co => 'CO',
      _Metric.no2 => 'NO₂',
    };
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.activeMetrics});
  final Set<_Metric> activeMetrics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AtmosphereTokens.space16),
      child: Wrap(
        spacing: AtmosphereTokens.space16,
        runSpacing: AtmosphereTokens.space8,
        alignment: WrapAlignment.center,
        children: [
          if (activeMetrics.contains(_Metric.temp))
            _Legend(color: c.danger, label: 'Temperature (°C)'),
          if (activeMetrics.contains(_Metric.humidity))
            _Legend(color: c.accent, label: 'Humidity (%)'),
          if (activeMetrics.contains(_Metric.co))
            _Legend(color: c.brand, label: 'CO (ppm)'),
          if (activeMetrics.contains(_Metric.no2))
            const _Legend(color: Color(0xFF7A4FD0), label: 'NO₂ (ppm)'),
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
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: AtmosphereTokens.space6),
        Text(label, style: AtmosphereTextStyles.caption(c.ink3)),
      ],
    );
  }
}
