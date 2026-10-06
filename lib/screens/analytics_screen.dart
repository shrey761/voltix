import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/energy_models.dart';
import '../services/energy_service.dart';
import '../services/tariff_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final energyService = EnergyService();
    final tariffService = TariffService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Weekly & Historical Analytics",
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

              // Compute complete historical daily room breakdown from Firebase readings
              final dailyBreakdown = EnergyCalculator.computeDailyRoomBreakdown(
                readings,
                tariffRate: tariffService.tariffRate,
              );

              // Calculate weekly total
              double weeklyTotal = analytics?.weeklyTotalUnits ?? 0.0;
              if (weeklyTotal == 0.0 && readings.isNotEmpty) {
                final startOfWeek = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
                final startOfW = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
                final wReadings = readings.where((r) => r.timestamp.isAfter(startOfW) || r.timestamp.isAtSameMomentAs(startOfW)).toList();
                if (wReadings.isNotEmpty) {
                  weeklyTotal = EnergyCalculator.computeEnergyKWh(wReadings);
                }
              }

              // Extract daily bars
              List<DailyBarItem> bars = analytics?.dailyBars ?? [];
              if (bars.isEmpty) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                bars = List.generate(7, (i) {
                  // Find energy from dailyBreakdown for that day of current week if available
                  double dayUnits = 0.0;
                  final now = DateTime.now();
                  final targetDay = now.subtract(Duration(days: now.weekday - 1 - i));
                  final targetDateStr = "${targetDay.year.toString().padLeft(4, '0')}-"
                      "${targetDay.month.toString().padLeft(2, '0')}-"
                      "${targetDay.day.toString().padLeft(2, '0')}";

                  for (final d in dailyBreakdown) {
                    if (d.date == targetDateStr) {
                      dayUnits = d.totalEnergyKWh;
                      break;
                    }
                  }

                  if (dayUnits == 0.0 && i == now.weekday - 1) {
                    dayUnits = weeklyTotal;
                  }

                  return DailyBarItem(
                    dayIndex: i,
                    dayName: days[i],
                    date: targetDateStr,
                    units: dayUnits,
                  );
                });
              }

              // Max bar height
              double maxBarUnits = 1.0;
              for (var b in bars) {
                if (b.units > maxBarUnits) maxBarUnits = b.units;
              }
              maxBarUnits = (maxBarUnits * 1.25).clamp(1.0, 100.0);

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
                            "${weeklyTotal.toStringAsFixed(3)} kWh",
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
                    // HISTORICAL DAILY & ROOM-WISE ENERGY BREAKDOWN
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
                                "Daily & Room-Wise History",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Preserved by Date",
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Cumulative daily consumption preserved across calendar dates",
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          if (dailyBreakdown.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  "No historical days recorded yet.",
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            _buildDailyBreakdownTable(dailyBreakdown),
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

  static Widget _buildDailyBreakdownTable(List<DailyRoomEnergy> dailyList) {
    // Show in reverse chronological order (newest date first)
    final reversed = dailyList.reversed.toList();

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  "DATE",
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "ROOM 1",
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "ROOM 2",
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "TOTAL",
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "BILL",
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Table Rows
        ...reversed.map((d) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.date,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        d.dayName,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "${d.room1EnergyKWh.toStringAsFixed(3)} kWh",
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "${d.room2EnergyKWh.toStringAsFixed(3)} kWh",
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "${d.totalEnergyKWh.toStringAsFixed(3)} kWh",
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "₹${d.estimatedBill.toStringAsFixed(2)}",
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
                      color: val >= 40.0
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