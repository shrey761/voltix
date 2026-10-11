import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/energy_models.dart';
import '../services/energy_service.dart';

class PredictionScreen extends StatelessWidget {
  const PredictionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final energyService = EnergyService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Prediction Insights",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<PredictionResult?>(
        stream: energyService.predictionsStream,
        builder: (context, predSnapshot) {
          final pred = predSnapshot.data;

          return StreamBuilder<EnergyReading?>(
            stream: energyService.latestReadingStream,
            builder: (context, readingSnap) {
              final reading = readingSnap.data;
              final double p1 = reading?.power1 ?? pred?.room1.currentPower ?? 0.0;
              final double p2 = reading?.power2 ?? pred?.room2.currentPower ?? 0.0;
              final double totalP = reading?.totalPower ?? (p1 + p2);

              final bool hasPrediction = pred != null;
              final r1Next = pred?.room1.nextHourState ?? (p1 >= 40.0 ? "HIGH USAGE" : "NORMAL");
              final r1NextConf = pred?.room1.nextHourConfidence ?? 0.0;
              final r1Tmrw = pred?.room1.tomorrowState ?? "NORMAL";
              final r1TmrwConf = pred?.room1.tomorrowConfidence ?? 0.0;
              final r1PredP = pred?.room1.predictedPower ?? p1;

              final r2Next = pred?.room2.nextHourState ?? (p2 >= 10.0 ? "HIGH USAGE" : "NORMAL");
              final r2NextConf = pred?.room2.nextHourConfidence ?? 0.0;
              final r2Tmrw = pred?.room2.tomorrowState ?? "NORMAL";
              final r2TmrwConf = pred?.room2.tomorrowConfidence ?? 0.0;
              final r2PredP = pred?.room2.predictedPower ?? p2;

              final double totalPredP = r1PredP + r2PredP;

              final List<String> allRecs = [];
              if (pred != null) {
                allRecs.addAll(pred.room1.recommendations);
                allRecs.addAll(pred.room2.recommendations);
              } else {
                if (r1Next == "HIGH USAGE") allRecs.add("Reduce non-essential loads in Room 1 during next hour.");
                if (r2Next == "HIGH USAGE") allRecs.add("Reduce non-essential loads in Room 2 during next hour.");
                if (r1Tmrw == "HIGH USAGE") allRecs.add("Shift heavy loads in Room 1 tomorrow around this time.");
                if (allRecs.isEmpty) allRecs.add("Normal usage expected. No immediate load reduction required.");
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!hasPrediction && reading == null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.hourglass_empty, color: Colors.orange.withValues(alpha: 0.8), size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              "Prediction unavailable — collecting more data",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Not enough historical telemetry for AI prediction yet. Real-time inference will populate once data arrives.",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    // ==================================================
                    // TOTAL PREDICTION OVERVIEW CARD
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Predicted Immediate Power Load",
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (r1Next == "HIGH USAGE" || r2Next == "HIGH USAGE")
                                      ? Colors.redAccent.withValues(alpha: 0.2)
                                      : Colors.greenAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (r1Next == "HIGH USAGE" || r2Next == "HIGH USAGE")
                                      ? "HIGH LOAD RISK"
                                      : "OPTIMAL LOAD",
                                  style: TextStyle(
                                    color: (r1Next == "HIGH USAGE" || r2Next == "HIGH USAGE")
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${totalPredP.toStringAsFixed(1)} W",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Current Measured: ${totalP.toStringAsFixed(1)} W",
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // ROOM 1 & ROOM 2 MULTI-HORIZON CARDS
                    // ==================================================
                    buildRoomHorizonCard(
                      roomName: "Room 1",
                      currentPower: p1,
                      predictedPower: r1PredP,
                      nextHourState: r1Next,
                      nextHourConf: r1NextConf,
                      tomorrowState: r1Tmrw,
                      tomorrowConf: r1TmrwConf,
                      accentColor: Colors.orange,
                    ),
                    const SizedBox(height: 16),

                    buildRoomHorizonCard(
                      roomName: "Room 2",
                      currentPower: p2,
                      predictedPower: r2PredP,
                      nextHourState: r2Next,
                      nextHourConf: r2NextConf,
                      tomorrowState: r2Tmrw,
                      tomorrowConf: r2TmrwConf,
                      accentColor: Colors.blueAccent,
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // COMPARISON BAR CHART (MEASURED VS PREDICTED)
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
                            "Room Measured vs Predicted Power (Watts)",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 180,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxPower([p1, p2, r1PredP, r2PredP]),
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const labels = ['R1 Live', 'R1 Pred', 'R2 Live', 'R2 Pred'];
                                        if (value.toInt() < 0 || value.toInt() >= labels.length) {
                                          return const SizedBox();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            labels[value.toInt()],
                                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: [
                                  makeBar(0, p1, Colors.orange),
                                  makeBar(1, r1PredP, Colors.orangeAccent.withValues(alpha: 0.6)),
                                  makeBar(2, p2, Colors.blueAccent),
                                  makeBar(3, r2PredP, Colors.lightBlueAccent.withValues(alpha: 0.6)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // DYNAMIC INSIGHTS & RECOMMENDATIONS CARD
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
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 22),
                              SizedBox(width: 8),
                              Text(
                                "Prediction Insights & Actions",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...allRecs.map((rec) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.orange, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        rec,
                                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
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

  static Widget buildRoomHorizonCard({
    required String roomName,
    required double currentPower,
    required double predictedPower,
    required String nextHourState,
    required double nextHourConf,
    required String tomorrowState,
    required double tomorrowConf,
    required Color accentColor,
  }) {
    final bool isNextHigh = nextHourState == "HIGH USAGE";
    final bool isTmrwHigh = tomorrowState == "HIGH USAGE";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                roomName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Live: ${currentPower.toStringAsFixed(0)} W",
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Next Hour Prediction
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Next Hour Horizon", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isNextHigh ? Colors.redAccent.withValues(alpha: 0.2) : Colors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          nextHourState,
                          style: TextStyle(
                            color: isNextHigh ? Colors.redAccent : Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Confidence", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    nextHourConf > 0 ? "${nextHourConf.toStringAsFixed(0)}%" : "Pending",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tomorrow Same-Hour Prediction
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tomorrow Same-Hour", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isTmrwHigh ? Colors.orangeAccent.withValues(alpha: 0.2) : Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tomorrowState,
                      style: TextStyle(
                        color: isTmrwHigh ? Colors.orangeAccent : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Confidence", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    tomorrowConf > 0 ? "${tomorrowConf.toStringAsFixed(0)}%" : "Pending",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static double maxPower(List<double> values) {
    double m = 100.0;
    for (var v in values) {
      if (v > m) m = v;
    }
    return m * 1.15;
  }

  static BarChartGroupData makeBar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 24,
          borderRadius: BorderRadius.circular(6),
          color: color,
        ),
      ],
    );
  }
}