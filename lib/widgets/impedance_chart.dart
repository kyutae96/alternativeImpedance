/// Impedance Chart Widget
/// Based on LineChart from ImpedanceCombindation1Fragment.kt

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';

class ImpedanceChart extends StatelessWidget {
  final Map<int, double> measurements;
  final String title;
  final Color lineColor;
  final int channelOffset;
  final Function(int channel, double value, int frequency)? onPointSelected;

  const ImpedanceChart({
    super.key,
    required this.measurements,
    required this.title,
    this.lineColor = Colors.red,
    this.channelOffset = 0,
    this.onPointSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '데이터 없음',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Create spots using frequency as X-axis
    final spots = <FlSpot>[];
    final sortedKeys = measurements.keys.toList()..sort();

    for (final key in sortedKeys) {
      final channelIndex = ((key - 1) % 16) + 1;
      final frequency = AppConstants.frequencyMapping[channelIndex]?.toDouble() ?? 0;
      spots.add(FlSpot(frequency, measurements[key]!));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 2000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 0.5,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Text(
              '주파수 (Hz)',
              style: TextStyle(fontSize: 10),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 3000,
              getTitlesWidget: (value, meta) {
                if (value <= 0 || value > 15000) return const SizedBox();
                return Text(
                  _formatFrequency(value.toInt()),
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade400),
        ),
        minX: 0,
        maxX: 16000,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: Colors.black,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final frequency = spot.x.toInt();
                final value = spot.y;
                return LineTooltipItem(
                  '주파수: ${_formatFrequency(frequency)} Hz\n'
                  '임피던스: ${value.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && 
                response?.lineBarSpots != null &&
                response!.lineBarSpots!.isNotEmpty &&
                onPointSelected != null) {
              final spot = response.lineBarSpots![0];
              final spotIndex = spot.spotIndex;
              final channel = sortedKeys[spotIndex];
              final frequency = spot.x.toInt();
              final value = spot.y;
              onPointSelected!(channel, value, frequency);
            }
          },
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  String _formatFrequency(int frequency) {
    if (frequency >= 1000) {
      final kHz = frequency / 1000;
      return '${kHz.toStringAsFixed(kHz.truncateToDouble() == kHz ? 0 : 1)}k';
    }
    return frequency.toString();
  }
}
