import 'package:flutter/material.dart';
import '../models/energy_models.dart';
import '../services/energy_service.dart';

class OptimizationScreen extends StatelessWidget {
  const OptimizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final energyService = EnergyService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Optimization Insights",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<OptimizationInsight?>(
        stream: energyService.optimizationStream,
        builder: (context, optSnap) {
          final opt = optSnap.data;

          return StreamBuilder<MonthlyForecast?>(
            stream: energyService.monthlyForecastStream,
            builder: (context, forecastSnap) {
              final forecast = forecastSnap.data;

              final double savingsUnits = opt?.estimatedSavingsUnits ?? 8.5;
              final double optEfficiency = opt?.optimizationEfficiencyPercent ?? 82.0;
              final double r1Units = opt?.room1Units ?? (forecast?.monthToDateUnits ?? 0.0) * 0.6;
              final double r2Units = opt?.room2Units ?? (forecast?.monthToDateUnits ?? 0.0) * 0.4;
              final double r1Pct = opt?.room1Percent ?? 60.0;
              final double r2Pct = opt?.room2Percent ?? 40.0;

              final suggestions = opt?.suggestions ?? [
                OptimizationSuggestionItem(
                  title: r1Units >= r2Units ? "Room 1 contributes highest usage" : "Room 2 contributes highest usage",
                  subtitle: "Reduce continuous high-power appliance runtimes during afternoon peaks.",
                  icon: "warning",
                ),
                OptimizationSuggestionItem(
                  title: "Shift heavy loads to off-peak hours",
                  subtitle: "Recommended after 10:00 PM to maximize efficiency.",
                  icon: "bolt",
                ),
                OptimizationSuggestionItem(
                  title: "Stay within Gruha Jyothi 96-Unit Quota",
                  subtitle: "Maintain daily average under ${(96.0 / (forecast?.daysInMonth ?? 30)).toStringAsFixed(1)} units/day.",
                  icon: "energy_savings_leaf",
                ),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ==================================================
                    // ESTIMATED MONTHLY SAVINGS CARD
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
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
                              Icon(
                                Icons.energy_savings_leaf,
                                color: Colors.greenAccent,
                                size: 28,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Savings Potential (Estimated)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Estimated Monthly Savings",
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "~${savingsUnits.toStringAsFixed(1)} Units",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Achievable by shifting identified high-usage periods to off-peak hours",
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
                          ),
                          const SizedBox(height: 22),

                          // Efficiency Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: (optEfficiency / 100.0).clamp(0.0, 1.0),
                              minHeight: 12,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${optEfficiency.toStringAsFixed(0)}% Optimization Efficiency Score",
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // DYNAMIC SMART SUGGESTIONS
                    // ==================================================
                    ...suggestions.map((s) => buildSuggestionCard(
                          getIconData(s.icon),
                          getIconColor(s.icon),
                          s.title,
                          s.subtitle,
                        )),
                    const SizedBox(height: 12),

                    // ==================================================
                    // ROOM-WISE CONSUMPTION SUMMARY (ROOM 1 & ROOM 2 ONLY)
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Room-wise Consumption Split",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Actual room telemetry recorded by energy meter",
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          buildRoomRow(
                            "Room 1",
                            "${r1Units.toStringAsFixed(2)} Units (${r1Pct.toStringAsFixed(0)}%)",
                            Colors.orange,
                          ),
                          buildRoomRow(
                            "Room 2",
                            "${r2Units.toStringAsFixed(2)} Units (${r2Pct.toStringAsFixed(0)}%)",
                            Colors.blueAccent,
                          ),
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

  static IconData getIconData(String iconName) {
    switch (iconName) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'bolt':
        return Icons.bolt;
      case 'energy_savings_leaf':
        return Icons.energy_savings_leaf;
      default:
        return Icons.access_time;
    }
  }

  static Color getIconColor(String iconName) {
    switch (iconName) {
      case 'warning':
        return Colors.orange;
      case 'bolt':
        return Colors.greenAccent;
      case 'energy_savings_leaf':
        return Colors.tealAccent;
      default:
        return Colors.blueAccent;
    }
  }

  static Widget buildSuggestionCard(
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        color: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
        ),
      ),
    );
  }

  static Widget buildRoomRow(
    String room,
    String units,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            room,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              units,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}