import 'package:flutter/material.dart';
import '../models/energy_models.dart';
import '../services/energy_service.dart';
import '../widgets/data_card.dart';
import 'analytics_screen.dart';
import 'prediction_screen.dart';
import 'optimization_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double allocatedUnits = 96.0;

  @override
  Widget build(BuildContext context) {
    final energyService = EnergyService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Voltix",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Notifications
          StreamBuilder<List<EnergyNotification>>(
            stream: energyService.notificationsStream,
            builder: (context, notifSnap) {
              final count = notifSnap.data?.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // Analytics
          IconButton(
            icon: const Icon(
              Icons.insights,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),

          // WiFi / Status
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.wifi,
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),

      body: StreamBuilder<EnergyReading?>(
        stream: energyService.latestReadingStream,
        builder: (context, readingSnapshot) {
          if (readingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (readingSnapshot.hasError) {
            return Center(
              child: Text(
                "Firebase error:\n${readingSnapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final reading = readingSnapshot.data;
          if (reading == null) {
            return const Center(
              child: Text(
                "Waiting for ESP32 energy meter data...",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return StreamBuilder<MonthlyForecast?>(
            stream: energyService.monthlyForecastStream,
            builder: (context, forecastSnap) {
              final forecast = forecastSnap.data ??
                  EnergyService.computeForecastFromReadings(reading, [reading]);

              final double usedUnits = forecast.monthToDateUnits;
              final double remainingUnits = forecast.remainingUnits;
              final double usagePercentage = forecast.usagePercentage;
              final double projectedEnd = forecast.projectedMonthEndUnits;

              String warningMessage;
              if (usedUnits >= allocatedUnits) {
                warningMessage = "Your free 96-unit limit has been exceeded.";
              } else if (usagePercentage >= 0.85) {
                warningMessage = "Warning: ${(usagePercentage * 100).toStringAsFixed(0)}% of your 96 free units used.";
              } else if (forecast.projectedExcessUnits > 0) {
                warningMessage = "Usage trend projects ${projectedEnd.toStringAsFixed(1)} Units by month-end.";
              } else {
                warningMessage = "Your electricity usage is within the 96-unit Gruha Jyothi quota.";
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ==================================================
                    // GRUHA JYOTHI CARD (MONTH-TO-DATE CALCULATED)
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
                          // TITLE
                          const Row(
                            children: [
                              Icon(
                                Icons.energy_savings_leaf,
                                color: Colors.greenAccent,
                                size: 28,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Gruha Jyothi Status",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ALLOCATION ROW
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              buildStatusColumn(
                                "Allocated",
                                "${allocatedUnits.toStringAsFixed(0)} Units",
                                Colors.blue,
                              ),
                              buildStatusColumn(
                                "Month-to-Date",
                                "${usedUnits.toStringAsFixed(2)} Units",
                                Colors.orange,
                              ),
                              buildStatusColumn(
                                "Remaining",
                                "${remainingUnits.toStringAsFixed(2)} Units",
                                Colors.greenAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),

                          // MONTHLY USAGE PROGRESS BAR
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Monthly Usage Progress",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    "Projected: ${projectedEnd.toStringAsFixed(1)} Units",
                                    style: TextStyle(
                                      color: forecast.projectedExcessUnits > 0 ? Colors.orangeAccent : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: usagePercentage.clamp(0.0, 1.0),
                                  minHeight: 12,
                                  backgroundColor: Colors.white12,
                                  valueColor: AlwaysStoppedAnimation(
                                    usagePercentage >= 0.85 ? Colors.redAccent : Colors.orange,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "${usedUnits.toStringAsFixed(2)} / ${allocatedUnits.toStringAsFixed(0)} Units Used (${(usagePercentage * 100).toStringAsFixed(1)}%)",
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // WARNING BANNER
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: usagePercentage >= 0.85
                                  ? Colors.red.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  usagePercentage >= 0.85
                                      ? Icons.error_outline
                                      : Icons.warning_amber_rounded,
                                  color: usagePercentage >= 0.85 ? Colors.redAccent : Colors.orange,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    warningMessage,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // REAL-TIME SENSOR DATA CARDS
                    // ==================================================
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        DataCard(
                          title: "Voltage",
                          value: "${reading.voltage1.toStringAsFixed(1)} V",
                          icon: Icons.bolt,
                        ),
                        DataCard(
                          title: "Current",
                          value: "${reading.totalCurrent.toStringAsFixed(2)} A",
                          icon: Icons.flash_on,
                        ),
                        DataCard(
                          title: "Power",
                          value: "${(reading.totalPower / 1000.0).toStringAsFixed(2)} kW",
                          icon: Icons.electric_meter,
                        ),
                        DataCard(
                          title: "Cumulative Energy",
                          value: "${reading.totalEnergy.toStringAsFixed(3)} kWh",
                          icon: Icons.battery_charging_full,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // PREDICTION PREVIEW CARD (CONNECTS TO ML)
                    // ==================================================
                    StreamBuilder<PredictionResult?>(
                      stream: energyService.predictionsStream,
                      builder: (context, predSnap) {
                        final pred = predSnap.data;
                        final String predSubtitle = pred != null
                            ? "R1: ${pred.room1.nextHourState} • R2: ${pred.room2.nextHourState}"
                            : "Live Random Forest ML predictions";

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PredictionScreen(),
                              ),
                            );
                          },
                          child: Card(
                            color: const Color(0xFF1C1C1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.trending_up,
                                color: Colors.redAccent,
                              ),
                              title: const Text(
                                "Predicted Usage (AI Advisor)",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                predSubtitle,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white38,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // ==================================================
                    // OPTIMIZATION PREVIEW CARD
                    // ==================================================
                    StreamBuilder<OptimizationInsight?>(
                      stream: energyService.optimizationStream,
                      builder: (context, optSnap) {
                        final opt = optSnap.data;
                        final String optSubtitle = opt != null
                            ? "Potential Savings: ~${opt.estimatedSavingsUnits.toStringAsFixed(1)} Units"
                            : "Based on active room consumption";

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const OptimizationScreen(),
                              ),
                            );
                          },
                          child: Card(
                            color: const Color(0xFF1C1C1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.energy_savings_leaf,
                                color: Colors.orange,
                              ),
                              title: const Text(
                                "Optimization Suggestions",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                optSubtitle,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white38,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // FOOTER
                    Text(
                      "Live data from ESP32 • Voltix AI Engine",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 12,
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

  static Widget buildStatusColumn(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}