import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';

class WeeklyVelocityChart extends StatelessWidget {
  final List<Map<String, dynamic>> activityData;

  const WeeklyVelocityChart({super.key, required this.activityData});

  @override
  Widget build(BuildContext context) {
    if (activityData.isEmpty) return const SizedBox();

    double maxCards = 0;
    for (var data in activityData) {
      if (data['cardsReviewed'] > maxCards) {
        maxCards = (data['cardsReviewed'] as int).toDouble();
      }
    }
    if (maxCards == 0) maxCards = 10;

    return Container(
      height: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF162238),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3B5C)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF00B4D8)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCards * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < activityData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              activityData[value.toInt()]['day'],
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: activityData.asMap().entries.map((entry) {
                  final val = (entry.value['cardsReviewed'] as int).toDouble();
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: val == 0 ? 1.5 : val,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00B4D8), Color(0xFF10B981)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MasteryChart extends StatelessWidget {
  final List<Map<String, dynamic>> masteryData;

  const MasteryChart({super.key, required this.masteryData});

  @override
  Widget build(BuildContext context) {
    if (masteryData.isEmpty) return const SizedBox();

    return Container(
      height: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF162238),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3B5C)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Algorithm Mastery',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.psychology_rounded, size: 18, color: Color(0xFFF97316)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: const Color(0x33A855F7),
                    borderColor: const Color(0xFFF97316),
                    entryRadius: 4,
                    dataEntries: masteryData.map((data) {
                      return RadarEntry(value: (data['level'] as num).toDouble());
                    }).toList(),
                    borderWidth: 2,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Color(0xFF2A3B5C)),
                tickCount: 4,
                ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                tickBorderData: const BorderSide(color: Color(0xFF1E293B), width: 0.5),
                gridBorderData: const BorderSide(color: Color(0xFF2A3B5C), width: 1),
                getTitle: (index, angle) {
                  if (index >= 0 && index < masteryData.length) {
                    return RadarChartTitle(
                      text: masteryData[index]['subject'],
                      angle: 0,
                    );
                  }
                  return const RadarChartTitle(text: '');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
