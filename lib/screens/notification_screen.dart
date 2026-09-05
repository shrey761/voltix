import 'package:flutter/material.dart';
import '../models/energy_models.dart';
import '../services/energy_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final energyService = EnergyService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Notifications & Alerts",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<EnergyNotification>>(
        stream: energyService.notificationsStream,
        builder: (context, notifSnap) {
          final serverNotifs = notifSnap.data ?? [];

          return StreamBuilder<MonthlyForecast?>(
            stream: energyService.monthlyForecastStream,
            builder: (context, forecastSnap) {
              final forecast = forecastSnap.data;

              return StreamBuilder<PredictionResult?>(
                stream: energyService.predictionsStream,
                builder: (context, predSnap) {
                  final pred = predSnap.data;

                  // Merge server notifications with local dynamic rules if server stream is empty
                  List<EnergyNotification> activeList = List.from(serverNotifs);

                  if (activeList.isEmpty) {
                    if (forecast != null && forecast.projectedExcessUnits > 0) {
                      activeList.add(EnergyNotification(
                        id: "local_proj_exceed",
                        type: "warning",
                        title: "Projected Free Limit Exceed",
                        subtitle: "Projected month-end consumption is ${forecast.projectedMonthEndUnits.toStringAsFixed(1)} Units (exceeds 96-unit quota by ${forecast.projectedExcessUnits.toStringAsFixed(1)} Units). Additional charges may apply.",
                        timestamp: "Active",
                        priority: "HIGH",
                      ));
                    }

                    if (forecast != null && forecast.usagePercentage >= 0.85 && forecast.remainingUnits > 0) {
                      activeList.add(EnergyNotification(
                        id: "local_approaching_limit",
                        type: "warning",
                        title: "Approaching Free Unit Limit",
                        subtitle: "You have consumed ${forecast.monthToDateUnits.toStringAsFixed(1)} of 96 allocated units. Only ${forecast.remainingUnits.toStringAsFixed(1)} units remaining.",
                        timestamp: "Active",
                        priority: "HIGH",
                      ));
                    }

                    if (pred != null && pred.room1.nextHourState == "HIGH USAGE") {
                      activeList.add(EnergyNotification(
                        id: "local_r1_next",
                        type: "prediction",
                        title: "High Usage Expected in Room 1",
                        subtitle: "AI predicts high power load next hour (${pred.room1.nextHourConfidence.toStringAsFixed(0)}% confidence). Reduce non-essential loads.",
                        timestamp: "Next 1h",
                        priority: "MEDIUM",
                      ));
                    }

                    if (pred != null && pred.room2.nextHourState == "HIGH USAGE") {
                      activeList.add(EnergyNotification(
                        id: "local_r2_next",
                        type: "prediction",
                        title: "High Usage Expected in Room 2",
                        subtitle: "AI predicts high power load next hour (${pred.room2.nextHourConfidence.toStringAsFixed(0)}% confidence). Reduce non-essential loads.",
                        timestamp: "Next 1h",
                        priority: "MEDIUM",
                      ));
                    }

                    if (pred != null && pred.room1.tomorrowState == "HIGH USAGE") {
                      activeList.add(EnergyNotification(
                        id: "local_r1_tmrw",
                        type: "advance",
                        title: "Advance Alert: High Usage Tomorrow (Room 1)",
                        subtitle: "High energy consumption predicted in Room 1 tomorrow around this time (${pred.room1.tomorrowConfidence.toStringAsFixed(0)}% confidence). Plan to shift heavy loads.",
                        timestamp: "Tomorrow",
                        priority: "MEDIUM",
                      ));
                    }

                    if (pred != null && pred.room2.tomorrowState == "HIGH USAGE") {
                      activeList.add(EnergyNotification(
                        id: "local_r2_tmrw",
                        type: "advance",
                        title: "Advance Alert: High Usage Tomorrow (Room 2)",
                        subtitle: "High energy consumption predicted in Room 2 tomorrow around this time (${pred.room2.tomorrowConfidence.toStringAsFixed(0)}% confidence). Plan to shift heavy loads.",
                        timestamp: "Tomorrow",
                        priority: "MEDIUM",
                      ));
                    }

                    // Default healthy status if no warnings
                    if (activeList.isEmpty) {
                      activeList.add(EnergyNotification(
                        id: "local_optimal",
                        type: "optimal",
                        title: "All Rooms Operating Normally",
                        subtitle: "Electricity consumption is well within the 96-unit Gruha Jyothi quota and no peak anomalies are predicted.",
                        timestamp: "Just now",
                        priority: "LOW",
                      ));
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeList.length,
                    itemBuilder: (context, index) {
                      final item = activeList[index];
                      return buildNotificationCard(
                        icon: getNotificationIcon(item.type),
                        color: getNotificationColor(item.type, item.priority),
                        title: item.title,
                        subtitle: item.subtitle,
                        time: item.timestamp,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static IconData getNotificationIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'prediction':
        return Icons.trending_up;
      case 'advance':
        return Icons.event_note;
      case 'optimization':
        return Icons.energy_savings_leaf;
      case 'optimal':
        return Icons.check_circle_outline;
      default:
        return Icons.bolt;
    }
  }

  static Color getNotificationColor(String type, String priority) {
    if (priority == "HIGH") return Colors.redAccent;
    switch (type) {
      case 'warning':
        return Colors.orange;
      case 'prediction':
        return Colors.redAccent;
      case 'advance':
        return Colors.orangeAccent;
      case 'optimization':
        return Colors.greenAccent;
      case 'optimal':
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }

  static Widget buildNotificationCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}