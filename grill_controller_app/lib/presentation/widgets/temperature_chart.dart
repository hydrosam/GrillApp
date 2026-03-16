import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/temperature_reading.dart';

class TemperatureChart extends StatelessWidget {
  const TemperatureChart({
    super.key,
    required this.readings,
    this.height = 260,
  });

  final List<TemperatureReading> readings;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF4E7D4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No temperature points yet'),
      );
    }

    final grouped = <ProbeType, List<TemperatureReading>>{};
    for (final reading in readings) {
      grouped.putIfAbsent(reading.type, () => []).add(reading);
    }

    final ordered = [...readings]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final first = ordered.first.timestamp;

    final colors = <ProbeType, Color>{
      ProbeType.grill: const Color(0xFFD45B37),
      ProbeType.food1: const Color(0xFF2D6A4F),
      ProbeType.food2: const Color(0xFF2D7DD2),
      ProbeType.food3: const Color(0xFF925E78),
    };

    final minY = readings.map((reading) => reading.temperature).reduce(
          (value, element) => value < element ? value : element,
        );
    final maxY = readings.map((reading) => reading.temperature).reduce(
          (value, element) => value > element ? value : element,
        );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - 10,
          maxY: maxY + 10,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFE8D9C3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF8B6D4B),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xFFDBC6A7)),
          ),
          lineBarsData: grouped.entries.map((entry) {
            final spots = entry.value
                .map((reading) => FlSpot(
                      reading.timestamp.difference(first).inMinutes.toDouble(),
                      reading.temperature,
                    ))
                .toList();
            return LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colors[entry.key],
              barWidth: 3,
              dotData: const FlDotData(show: false),
            );
          }).toList(),
        ),
      ),
    );
  }
}
