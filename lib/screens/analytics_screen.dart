import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/energy_models.dart';
import '../services/energy_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final energyService = EnergyService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Weekly Analytics",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<AnalyticsData?>(
        stream: energyService.analyticsStream,
        builder: (context, analyticsSnap) {
          final analytics = analyticsSnap.data;

          return StreamBuilder<List<EnergyReading>>(
            stream: energyService.recentReadingsStream,
            builder: (context, readingsSnap) {
              final readings = readingsSnap.data ?? [];

              // Calculate weekly total
              double weeklyTotal = analytics?.weeklyTotalUnits ?? 0.0;
              if (weeklyTotal == 0.0 && readings.isNotEmpty) {
                final startOfWeek = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
                final wReadings = readings.where((r) => r.timestamp.isAfter(startOfWeek) || r.timestamp.isAtSameMomentAs(startOfWeek)).toList();
                if (wReadings.isNotEmpty) {
                  weeklyTotal = EnergyCalculator.computeEnergyKWh(wReadings);
                }
              }

              // Extract daily bars
              List<DailyBarItem> bars = analytics?.dailyBars ?? [];
              if (bars.isEmpty) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                bars = List.generate(7, (i) => DailyBarItem(
                  dayIndex: i,
                  dayName: days[i],
                  date: "",
                  units: (i == DateTime.now().weekday - 1) ? weeklyTotal : 0.0,
                ));
              }

              // Max bar height
              double maxBarUnits = 5.0;
              for (var b in bars) {
                if (b.units > maxBarUnits) maxBarUnits = b.units;
              }
              maxBarUnits = (maxBarUnits * 1.25).clamp(5.0, 100.0);

              // Hourly loads
              final h1 = analytics?.hourlyLoadRoom1 ?? List.filled(24, 0.0);
              final h2 = analytics?.hourlyLoadRoom2 ?? List.filled(24, 0.0);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ==================================================
                    // WEEKLY ENERGY REPORT CARD
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Weekly Energy Consumption",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${weeklyTotal.toStringAsFixed(2)} kWh",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Sum of recorded weekly energy deltas",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 28),

                          // 7-DAY BAR CHART
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxBarUnits,
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: maxBarUnits / 4,
                                  getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx < 0 || idx >= bars.length) return const SizedBox();
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            bars[idx].dayName,
                                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: List.generate(
                                  bars.length,
                                  (i) => makeBar(i, bars[i].units),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // PEAK USAGE HEATMAP (ROOM 1 & ROOM 2 ONLY)
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "24-Hour Peak Load Profile",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "00:00 → 23:00",
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          buildRoomPeakHeatmap("Room 1", h1, Colors.orange),
                          const SizedBox(height: 14),
                          buildRoomPeakHeatmap("Room 2", h2, Colors.blueAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static BarChartGroupData makeBar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 22,
          borderRadius: BorderRadius.circular(6),
          color: Colors.orange,
        ),
      ],
    );
  }

  static Widget buildRoomPeakHeatmap(String room, List<double> hourlyWatts, Color baseColor) {
    double maxW = 1.0;
    for (var w in hourlyWatts) {
      if (w > maxW) maxW = w;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                room,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                "Peak: ${maxW.toStringAsFixed(0)} W",
                style: TextStyle(color: baseColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(24, (hourIndex) {
              final val = (hourIndex < hourlyWatts.length) ? hourlyWatts[hourIndex] : 0.0;
              final intensity = (val / maxW).clamp(0.1, 1.0);

              return Expanded(
                child: Tooltip(
                  message: "$hourIndex:00 - ${val.toStringAsFixed(0)} W",
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: 20,
                    decoration: BoxDecoration(
                      color: val > 1200
                          ? Colors.redAccent
                          : baseColor.withValues(alpha: intensity),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}