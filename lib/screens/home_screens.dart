import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/energy_models.dart';
import '../services/energy_service.dart';
import '../services/tariff_service.dart';
import '../widgets/data_card.dart';
import 'analytics_screen.dart';
import 'prediction_screen.dart';
import 'optimization_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final energyService = EnergyService();
    final tariffService = TariffService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "VOLTIX",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              "Energy Monitoring",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          // Active Notifications Bell with Badge
          StreamBuilder<List<EnergyNotification>>(
            stream: energyService.notificationsStream,
            builder: (context, notifSnap) {
              final actionableCount = notifSnap.data
                      ?.where((n) =>
                          n.type.toLowerCase() != 'optimal' &&
                          n.priority.toUpperCase() != 'LOW')
                      .length ??
                  0;
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
                  if (actionableCount > 0)
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
                          '$actionableCount',
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

          // Analytics Shortcut
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

          // Realtime Connection Pulse
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(
              Icons.wifi,
              color: Colors.greenAccent,
              size: 20,
            ),
          ),
        ],
      ),

      body: ValueListenableBuilder<double>(
        valueListenable: tariffService.tariffRateNotifier,
        builder: (context, tariffRate, _) {
          return ValueListenableBuilder<double>(
            valueListenable: tariffService.quotaUnitsNotifier,
            builder: (context, quotaUnits, _) {
              return StreamBuilder<List<EnergyReading>>(
                stream: energyService.recentReadingsStream,
                builder: (context, historySnap) {
                  final history = historySnap.data ?? [];

                  return StreamBuilder<EnergyReading?>(
                    stream: energyService.latestReadingStream,
                    builder: (context, readingSnapshot) {
                      final reading = readingSnapshot.data ?? (history.isNotEmpty ? history.last : null);
                      final metrics = EnergyCalculator.calculateMetrics(
                        latest: reading,
                        history: history,
                        tariffRate: tariffRate,
                      );

                      return StreamBuilder<PredictionResult?>(
                        stream: energyService.predictionsStream,
                        builder: (context, predSnap) {
                          final prediction = predSnap.data;

                          return RefreshIndicator(
                            onRefresh: () async {
                              // Realtime StreamBuilder automatically syncs with Firebase
                              await Future.delayed(const Duration(milliseconds: 300));
                            },
                            color: Colors.orange,
                            backgroundColor: const Color(0xFF1C1C1E),
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ==================================================
                                  // 1. HERO CARD: CURRENT POWER & DEVICE STATUS
                                  // ==================================================
                                  _buildCurrentPowerHeroCard(metrics),
                                  const SizedBox(height: 16),

                                  // ==================================================
                                  // 2. ACCUMULATED ENERGY & COST METRICS (3 CARDS)
                                  // ==================================================
                                  _buildAccumulatedMetricsRow(metrics),
                                  const SizedBox(height: 18),

                                  // ==================================================
                                  // 3. REAL HISTORICAL ENERGY USAGE GRAPH
                                  // ==================================================
                                  _buildHistoricalGraphSection(metrics),
                                  const SizedBox(height: 18),

                                  // ==================================================
                                  // 4. PREDICTIVE LOAD SECTION
                                  // ==================================================
                                  _buildPredictiveLoadSection(context, prediction, metrics),
                                  const SizedBox(height: 18),

                                  // ==================================================
                                  // 5. LIVE ELECTRICAL SENSOR GRID
                                  // ==================================================
                                  _buildElectricalGrid(reading),
                                  const SizedBox(height: 18),

                                  // ==================================================
                                  // 6. ENERGY CONSUMPTION QUOTA PROGRESS CARD
                                  // ==================================================
                                  _buildQuotaCard(metrics, quotaUnits),
                                  const SizedBox(height: 18),

                                  // ==================================================
                                  // 7. OPTIMIZATION SHORTCUT CARD
                                  // ==================================================
                                  _buildOptimizationCard(context, energyService),
                                  const SizedBox(height: 20),

                                  // FOOTER
                                  Center(
                                    child: Text(
                                      "ESP32 Telemetry • Random Forest Inference • Voltix Engine",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          );
                        },
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

  // =========================================================================
  // WIDGET BUILDERS
  // =========================================================================

  /// 1. Current Power Hero Card (W & ON/OFF)
  static Widget _buildCurrentPowerHeroCard(RealEnergyMetrics metrics) {
    final bool isOn = metrics.isDeviceOn;
    final double power = metrics.currentPower;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOn ? Colors.orange.withValues(alpha: 0.3) : Colors.white10,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn ? Colors.orange.withValues(alpha: 0.08) : Colors.black,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "CURRENT POWER",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOn
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOn ? Colors.greenAccent : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOn ? Colors.greenAccent : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOn ? "ON" : "OFF",
                      style: TextStyle(
                        color: isOn ? Colors.greenAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                power.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "W",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOn
                ? "Active instantaneous load measured at current timestamp"
                : "No active power consumption detected (Load is OFF)",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Accumulated Energy & Cost Metrics (Today, This Month, Monthly Bill)
  static Widget _buildAccumulatedMetricsRow(RealEnergyMetrics metrics) {
    return Row(
      children: [
        // TODAY'S ENERGY
        Expanded(
          child: _buildMetricCard(
            title: "TODAY'S ENERGY",
            value: "${metrics.todayEnergyKWh.toStringAsFixed(2)} kWh",
            subtitle: "Bill: ₹${metrics.todayEstimatedBill.toStringAsFixed(2)}",
            icon: Icons.today,
            accentColor: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 10),

        // THIS MONTH
        Expanded(
          child: _buildMetricCard(
            title: "THIS MONTH",
            value: "${metrics.thisMonthEnergyKWh.toStringAsFixed(2)} kWh",
            subtitle: "Calendar Month",
            icon: Icons.calendar_month,
            accentColor: Colors.purpleAccent,
          ),
        ),
        const SizedBox(width: 10),

        // MONTHLY ESTIMATED BILL
        Expanded(
          child: _buildMetricCard(
            title: "ESTIMATED BILL",
            value: "₹${metrics.estimatedBill.toStringAsFixed(2)}",
            subtitle: "Monthly @ ₹${metrics.tariffRate.toStringAsFixed(2)}",
            icon: Icons.currency_rupee,
            accentColor: Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  static Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 3. Real Historical Energy Usage Graph (fl_chart)
  static Widget _buildHistoricalGraphSection(RealEnergyMetrics metrics) {
    final readings = metrics.recentHistory;

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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: Colors.orangeAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "ENERGY USAGE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                "Power (W) vs Time",
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chart or Empty State
          if (readings.isEmpty)
            Container(
              height: 160,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.electric_meter_outlined,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No energy readings available yet",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Waiting for ESP32 energy meter telemetry...",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildChartWidget(readings),
        ],
      ),
    );
  }

  static Widget _buildChartWidget(List<EnergyReading> readings) {
    // Generate FlSpots from chronological readings
    final List<FlSpot> spots = [];
    double maxP = 100.0;

    for (int i = 0; i < readings.length; i++) {
      final p = readings[i].totalPower;
      if (p > maxP) maxP = p;
      spots.add(FlSpot(i.toDouble(), p));
    }
    maxP = (maxP * 1.2).clamp(100.0, 5000.0);

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (readings.length - 1).toDouble().clamp(1.0, double.infinity),
          minY: 0,
          maxY: maxP,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxP / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (readings.length / 4).clamp(1.0, double.infinity),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= readings.length) return const SizedBox();
                  final ts = readings[idx].timestamp;
                  final timeStr = "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orangeAccent,
              barWidth: 2.2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.orange.withValues(alpha: 0.35),
                    Colors.orange.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4. Predictive Load Section
  static Widget _buildPredictiveLoadSection(
    BuildContext context,
    PredictionResult? pred,
    RealEnergyMetrics metrics,
  ) {
    final bool hasPrediction = pred != null && metrics.totalReadingsCount >= 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasPrediction && pred.overallNextHourState == "HIGH USAGE"
              ? Colors.redAccent.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "PREDICTIVE LOAD",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (hasPrediction)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pred.overallNextHourState == "HIGH USAGE"
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pred.overallNextHourState == "HIGH USAGE" ? "HIGH LOAD RISK" : "OPTIMAL LOAD",
                    style: TextStyle(
                      color: pred.overallNextHourState == "HIGH USAGE" ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasPrediction)
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange.withValues(alpha: 0.7),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Prediction unavailable — collecting more data",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Not enough historical data for prediction yet. Load predictions will activate as telemetry accumulates.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Predicted Next Hour Load",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${pred.totalPredictedPower.toStringAsFixed(1)} W",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PredictionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics, color: Colors.blueAccent, size: 16),
                  label: const Text(
                    "Details",
                    style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Room 1: ${pred.room1.nextHourState} (${pred.room1.nextHourConfidence > 0 ? "${pred.room1.nextHourConfidence.toStringAsFixed(0)}%" : "Pending"}) • Room 2: ${pred.room2.nextHourState} (${pred.room2.nextHourConfidence > 0 ? "${pred.room2.nextHourConfidence.toStringAsFixed(0)}%" : "Pending"})",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 5. Live Electrical Sensor Grid (Voltage, Current, Room 1, Room 2)
  static Widget _buildElectricalGrid(EnergyReading? reading) {
    final double v1 = reading?.voltage1 ?? 230.0;
    final double current = reading?.totalCurrent ?? 0.0;
    final double p1 = reading?.power1 ?? 0.0;
    final double p2 = reading?.power2 ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        DataCard(
          title: "Voltage",
          value: "${v1.toStringAsFixed(1)} V",
          icon: Icons.bolt,
        ),
        DataCard(
          title: "Total Current",
          value: "${current.toStringAsFixed(2)} A",
          icon: Icons.flash_on,
        ),
        DataCard(
          title: "Room 1 Power",
          value: "${p1.toStringAsFixed(1)} W",
          icon: Icons.meeting_room,
        ),
        DataCard(
          title: "Room 2 Power",
          value: "${p2.toStringAsFixed(1)} W",
          icon: Icons.bedroom_parent,
        ),
      ],
    );
  }

  /// 6. Energy Consumption Quota Progress Card
  static Widget _buildQuotaCard(RealEnergyMetrics metrics, double quotaUnits) {
    final double used = metrics.thisMonthEnergyKWh;
    final double quota = quotaUnits > 0 ? quotaUnits : 96.0;
    final double remaining = (quota - used).clamp(0.0, quota);
    final double overflow = (used > quota) ? (used - quota) : 0.0;
    final double rawProgress = (quota > 0) ? (used / quota) : 0.0;
    final double progress = rawProgress.clamp(0.0, 1.0);
    final bool isExceeded = used > quota;
    final bool isWarning = !isExceeded && rawProgress >= 0.85;

    final Color statusColor = isExceeded
        ? Colors.redAccent
        : (isWarning ? Colors.orangeAccent : Colors.greenAccent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExceeded ? Colors.redAccent.withValues(alpha: 0.4) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.energy_savings_leaf, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Energy Consumption Quota",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 0.8),
                ),
                child: Text(
                  isExceeded
                      ? "LIMIT EXCEEDED"
                      : (isWarning
                          ? "${(rawProgress * 100).toStringAsFixed(1)}% (Near Limit)"
                          : "${(rawProgress * 100).toStringAsFixed(1)}% used"),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: isExceeded ? 1.0 : progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Allocated: ${quota.toStringAsFixed(0)} Units",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
              ),
              Text(
                isExceeded
                    ? "Exceeded by ${overflow.toStringAsFixed(2)} Units"
                    : "Remaining: ${remaining.toStringAsFixed(2)} Units",
                style: TextStyle(
                  color: isExceeded ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 7. Optimization Shortcut Card
  static Widget _buildOptimizationCard(BuildContext context, EnergyService energyService) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OptimizationScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Energy Optimization Suggestions",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Actionable recommendations to minimize electricity cost",
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }
}