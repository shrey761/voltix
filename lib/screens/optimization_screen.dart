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

              final double r1Units = opt?.room1Units ?? ((forecast?.monthToDateUnits ?? 0.0) * 0.5);
              final double r2Units = opt?.room2Units ?? ((forecast?.monthToDateUnits ?? 0.0) * 0.5);
              final double r1Pct = opt?.room1Percent ?? 50.0;
              final double r2Pct = opt?.room2Percent ?? 50.0;
              final double mtd = forecast?.monthToDateUnits ?? 0.0;
              final double projectedEnd = forecast?.projectedMonthEndUnits ?? 0.0;
              final double remaining = forecast?.remainingUnits ?? 96.0;

              final suggestions = opt?.suggestions ?? [
                OptimizationSuggestionItem(
                  title: r1Units >= r2Units ? "Room 1 is the primary energy contributor" : "Room 2 is the primary energy contributor",
                  subtitle: "Inspect high-wattage appliances and reduce idle runtime during active hours.",
                  icon: "warning",
                ),
                OptimizationSuggestionItem(
                  title: "Shift flexible loads to off-peak hours",
                  subtitle: "Running high-wattage equipment during non-peak hours optimizes grid efficiency.",
                  icon: "access_time",
                ),
                OptimizationSuggestionItem(
                  title: "Stay within Gruha Jyothi quota",
                  subtitle: "Maintain daily average under ${(96.0 / (forecast?.daysInMonth ?? 31)).toStringAsFixed(1)} units/day.",
                  icon: "energy_savings_leaf",
                ),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ==================================================
                    // OPTIMIZATION STATUS & QUOTA HEALTH CARD
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
                                "Optimization Opportunity",
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
                            "Current Quota Status",
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${mtd.toStringAsFixed(2)} / 96.0 Units Used",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            projectedEnd > 96.0
                                ? "Projected month-end: ${projectedEnd.toStringAsFixed(1)} Units (exceeds allocation by ${(projectedEnd - 96.0).toStringAsFixed(1)} Units)"
                                : "Projected month-end: ${projectedEnd.toStringAsFixed(1)} Units (within free 96-unit allocation)",
                            style: TextStyle(
                              color: projectedEnd > 96.0 ? Colors.orangeAccent : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Quota Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: (mtd / 96.0).clamp(0.0, 1.0),
                              minHeight: 12,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation(
                                (mtd / 96.0) >= 0.85 ? Colors.redAccent : Colors.greenAccent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${remaining.toStringAsFixed(2)} Units remaining this billing period",
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
              color: color.withValues(alpha: 0.15),
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
              color: color.withValues(alpha: 0.15),
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