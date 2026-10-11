// =========================================================================
// 1. RAW SENSOR READING MODEL
// =========================================================================
class EnergyReading {
  final String key;
  final DateTime timestamp;
  final double voltage1;
  final double voltage2;
  final double current1;
  final double current2;
  final double power1;
  final double power2;
  final double energy1;
  final double energy2;
  final double totalCurrent;
  final double totalPower;
  final double totalEnergy;

  EnergyReading({
    required this.key,
    required this.timestamp,
    required this.voltage1,
    required this.voltage2,
    required this.current1,
    required this.current2,
    required this.power1,
    required this.power2,
    required this.energy1,
    required this.energy2,
    required this.totalCurrent,
    required this.totalPower,
    required this.totalEnergy,
  });

  bool get isValidTimestamp => timestamp.year >= 2020;

  factory EnergyReading.fromMap(String key, Map<dynamic, dynamic> map) {
    DateTime ts;
    final dynamic tsVal = map['timestamp'];
    if (tsVal is String) {
      final parsed = DateTime.tryParse(tsVal);
      if (parsed != null && parsed.year >= 2020) {
        ts = parsed;
      } else {
        ts = DateTime.fromMillisecondsSinceEpoch(0);
      }
    } else {
      ts = DateTime.fromMillisecondsSinceEpoch(0);
    }

    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final p1 = parseD(map['power1']);
    final p2 = parseD(map['power2']);
    final c1 = parseD(map['current1']);
    final c2 = parseD(map['current2']);
    final e1 = parseD(map['energy1']);
    final e2 = parseD(map['energy2']);

    return EnergyReading(
      key: key,
      timestamp: ts,
      voltage1: parseD(map['voltage1']),
      voltage2: parseD(map['voltage2']),
      current1: c1,
      current2: c2,
      power1: p1,
      power2: p2,
      energy1: e1,
      energy2: e2,
      totalCurrent: map.containsKey('totalCurrent') ? parseD(map['totalCurrent']) : (c1 + c2),
      totalPower: map.containsKey('totalPower') ? parseD(map['totalPower']) : (p1 + p2),
      totalEnergy: map.containsKey('totalEnergy') ? parseD(map['totalEnergy']) : (e1 + e2),
    );
  }
}

// =========================================================================
// 2. ML ROOM PREDICTION MODEL
// =========================================================================
class RoomPredictionData {
  final double currentPower;
  final double predictedPower;
  final String nextHourState;
  final double nextHourConfidence;
  final String tomorrowState;
  final double tomorrowConfidence;
  final List<String> recommendations;

  RoomPredictionData({
    required this.currentPower,
    required this.predictedPower,
    required this.nextHourState,
    required this.nextHourConfidence,
    required this.tomorrowState,
    required this.tomorrowConfidence,
    required this.recommendations,
  });

  factory RoomPredictionData.fromMap(Map<dynamic, dynamic> map) {
    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final nextMap = map['nextHour'] is Map ? map['nextHour'] as Map : {};
    final tmrwMap = map['tomorrow'] is Map ? map['tomorrow'] as Map : {};

    List<String> recs = [];
    if (map['recommendations'] is List) {
      recs = (map['recommendations'] as List).map((e) => e.toString()).toList();
    }

    double nextConf = parseD(nextMap['confidencePercent']);
    if (nextConf == 0.0 && nextMap.containsKey('confidence')) {
      nextConf = parseD(nextMap['confidence']) * 100.0;
    }

    double tmrwConf = parseD(tmrwMap['confidencePercent']);
    if (tmrwConf == 0.0 && tmrwMap.containsKey('confidence')) {
      tmrwConf = parseD(tmrwMap['confidence']) * 100.0;
    }

    return RoomPredictionData(
      currentPower: parseD(map['currentPower']),
      predictedPower: parseD(map['predictedPower']),
      nextHourState: nextMap['state']?.toString() ?? "NORMAL",
      nextHourConfidence: nextConf,
      tomorrowState: tmrwMap['state']?.toString() ?? "NORMAL",
      tomorrowConfidence: tmrwConf,
      recommendations: recs,
    );
  }
}

class PredictionResult {
  final String timestamp;
  final RoomPredictionData room1;
  final RoomPredictionData room2;
  final double totalCurrentPower;
  final double totalPredictedPower;
  final String overallNextHourState;

  PredictionResult({
    required this.timestamp,
    required this.room1,
    required this.room2,
    required this.totalCurrentPower,
    required this.totalPredictedPower,
    required this.overallNextHourState,
  });

  factory PredictionResult.fromMap(Map<dynamic, dynamic> map) {
    final r1Map = map['room1'] is Map ? map['room1'] as Map : {};
    final r2Map = map['room2'] is Map ? map['room2'] as Map : {};
    final sumMap = map['summary'] is Map ? map['summary'] as Map : {};

    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final r1 = RoomPredictionData.fromMap(r1Map);
    final r2 = RoomPredictionData.fromMap(r2Map);

    return PredictionResult(
      timestamp: map['timestamp']?.toString() ?? DateTime.now().toString(),
      room1: r1,
      room2: r2,
      totalCurrentPower: sumMap.containsKey('totalCurrentPower')
          ? parseD(sumMap['totalCurrentPower'])
          : (r1.currentPower + r2.currentPower),
      totalPredictedPower: sumMap.containsKey('totalPredictedPower')
          ? parseD(sumMap['totalPredictedPower'])
          : (r1.predictedPower + r2.predictedPower),
      overallNextHourState: sumMap['overallNextHourState']?.toString() ??
          ((r1.nextHourState == "HIGH USAGE" || r2.nextHourState == "HIGH USAGE") ? "HIGH USAGE" : "NORMAL"),
    );
  }
}

// =========================================================================
// 3. STATISTICAL MONTHLY FORECAST & GRUHA JYOTHI MODEL
// =========================================================================
class MonthlyForecast {
  final double monthToDateUnits;
  final double todayUnits;
  final double weekUnits;
  final double averageDailyUnits;
  final double projectedMonthEndUnits;
  final double allocatedUnits;
  final double remainingUnits;
  final double projectedExcessUnits;
  final double usagePercentage;
  final int daysElapsed;
  final int daysInMonth;

  MonthlyForecast({
    required this.monthToDateUnits,
    required this.todayUnits,
    required this.weekUnits,
    required this.averageDailyUnits,
    required this.projectedMonthEndUnits,
    this.allocatedUnits = 96.0,
    required this.remainingUnits,
    required this.projectedExcessUnits,
    required this.usagePercentage,
    required this.daysElapsed,
    required this.daysInMonth,
  });

  factory MonthlyForecast.fromMap(Map<dynamic, dynamic> map) {
    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseI(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultVal;
    }

    final mtd = parseD(map['monthToDateUnits']);
    final alloc = parseD(map['allocatedUnits']) > 0.0 ? parseD(map['allocatedUnits']) : 96.0;
    final proj = parseD(map['projectedMonthEndUnits']);
    final excess = map.containsKey('projectedExcessUnits') ? parseD(map['projectedExcessUnits']) : (proj > alloc ? proj - alloc : 0.0);
    final remaining = map.containsKey('remainingUnits') ? parseD(map['remainingUnits']) : (alloc > mtd ? alloc - mtd : 0.0);

    return MonthlyForecast(
      monthToDateUnits: mtd,
      todayUnits: parseD(map['todayUnits']),
      weekUnits: parseD(map['weekUnits']),
      averageDailyUnits: parseD(map['averageDailyUnits']),
      projectedMonthEndUnits: proj,
      allocatedUnits: alloc,
      remainingUnits: remaining,
      projectedExcessUnits: excess,
      usagePercentage: map.containsKey('usagePercentage') ? parseD(map['usagePercentage']) : (mtd / alloc),
      daysElapsed: parseI(map['daysElapsed'], DateTime.now().day),
      daysInMonth: parseI(map['daysInMonth'], 30),
    );
  }
}

// =========================================================================
// 4. ANALYTICS & WEEKLY REPORT MODEL
// =========================================================================
class DailyBarItem {
  final int dayIndex;
  final String dayName;
  final String date;
  final double units;

  DailyBarItem({
    required this.dayIndex,
    required this.dayName,
    required this.date,
    required this.units,
  });

  factory DailyBarItem.fromMap(Map<dynamic, dynamic> map) {
    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }
    return DailyBarItem(
      dayIndex: map['dayIndex'] is int ? map['dayIndex'] : 0,
      dayName: map['dayName']?.toString() ?? "M",
      date: map['date']?.toString() ?? "",
      units: parseD(map['units']),
    );
  }
}

class AnalyticsData {
  final double weeklyTotalUnits;
  final List<DailyBarItem> dailyBars;
  final List<double> hourlyLoadRoom1;
  final List<double> hourlyLoadRoom2;
  final double room1MonthUnits;
  final double room2MonthUnits;

  AnalyticsData({
    required this.weeklyTotalUnits,
    required this.dailyBars,
    required this.hourlyLoadRoom1,
    required this.hourlyLoadRoom2,
    required this.room1MonthUnits,
    required this.room2MonthUnits,
  });

  factory AnalyticsData.fromMap(Map<dynamic, dynamic> map) {
    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    List<DailyBarItem> bars = [];
    if (map['dailyBars'] is List) {
      for (var item in map['dailyBars']) {
        if (item is Map) bars.add(DailyBarItem.fromMap(item));
      }
    }

    List<double> h1 = List.filled(24, 0.0);
    if (map['hourlyLoadRoom1'] is List) {
      final l = map['hourlyLoadRoom1'] as List;
      for (int i = 0; i < l.length && i < 24; i++) {
        h1[i] = parseD(l[i]);
      }
    }

    List<double> h2 = List.filled(24, 0.0);
    if (map['hourlyLoadRoom2'] is List) {
      final l = map['hourlyLoadRoom2'] as List;
      for (int i = 0; i < l.length && i < 24; i++) {
        h2[i] = parseD(l[i]);
      }
    }

    return AnalyticsData(
      weeklyTotalUnits: parseD(map['weeklyTotalUnits']),
      dailyBars: bars,
      hourlyLoadRoom1: h1,
      hourlyLoadRoom2: h2,
      room1MonthUnits: parseD(map['room1MonthUnits']),
      room2MonthUnits: parseD(map['room2MonthUnits']),
    );
  }
}

// =========================================================================
// 5. OPTIMIZATION INSIGHTS MODEL
// =========================================================================
class OptimizationSuggestionItem {
  final String title;
  final String subtitle;
  final String icon;

  OptimizationSuggestionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  factory OptimizationSuggestionItem.fromMap(Map<dynamic, dynamic> map) {
    return OptimizationSuggestionItem(
      title: map['title']?.toString() ?? "",
      subtitle: map['subtitle']?.toString() ?? "",
      icon: map['icon']?.toString() ?? "warning",
    );
  }
}

class OptimizationInsight {
  final double estimatedSavingsUnits;
  final double optimizationEfficiencyPercent;
  final double room1Units;
  final double room2Units;
  final double room1Percent;
  final double room2Percent;
  final List<OptimizationSuggestionItem> suggestions;

  OptimizationInsight({
    required this.estimatedSavingsUnits,
    required this.optimizationEfficiencyPercent,
    required this.room1Units,
    required this.room2Units,
    required this.room1Percent,
    required this.room2Percent,
    required this.suggestions,
  });

  factory OptimizationInsight.fromMap(Map<dynamic, dynamic> map) {
    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    List<OptimizationSuggestionItem> suggs = [];
    if (map['suggestions'] is List) {
      for (var item in map['suggestions']) {
        if (item is Map) suggs.add(OptimizationSuggestionItem.fromMap(item));
      }
    }

    return OptimizationInsight(
      estimatedSavingsUnits: parseD(map['estimatedSavingsUnits']),
      optimizationEfficiencyPercent: parseD(map['optimizationEfficiencyPercent']),
      room1Units: parseD(map['room1Units']),
      room2Units: parseD(map['room2Units']),
      room1Percent: parseD(map['room1Percent']),
      room2Percent: parseD(map['room2Percent']),
      suggestions: suggs,
    );
  }
}

// =========================================================================
// 6. DYNAMIC ENERGY NOTIFICATION MODEL
// =========================================================================
class EnergyNotification {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String timestamp;
  final String priority;

  EnergyNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.priority,
  });

  factory EnergyNotification.fromMap(Map<dynamic, dynamic> map) {
    return EnergyNotification(
      id: map['id']?.toString() ?? "",
      type: map['type']?.toString() ?? "general",
      title: map['title']?.toString() ?? "",
      subtitle: map['subtitle']?.toString() ?? "",
      timestamp: map['timestamp']?.toString() ?? "",
      priority: map['priority']?.toString() ?? "MEDIUM",
    );
  }
}

// =========================================================================
// 4.5. HISTORICAL DAILY & ROOM-WISE ENERGY MODEL
// =========================================================================
class DailyRoomEnergy {
  final String date;              // "YYYY-MM-DD"
  final String dayName;           // "Mon", "Tue", "Wednesday", etc.
  final double room1EnergyKWh;    // Room 1 cumulative difference
  final double room2EnergyKWh;    // Room 2 cumulative difference
  final double totalEnergyKWh;    // Room 1 + Room 2
  final double estimatedBill;     // totalEnergyKWh * tariffRate
  final int readingsCount;        // number of telemetry readings on that date

  DailyRoomEnergy({
    required this.date,
    required this.dayName,
    required this.room1EnergyKWh,
    required this.room2EnergyKWh,
    required this.totalEnergyKWh,
    required this.estimatedBill,
    required this.readingsCount,
  });

  factory DailyRoomEnergy.fromMap(Map<dynamic, dynamic> map) {
    double parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }
    return DailyRoomEnergy(
      date: map['date']?.toString() ?? "",
      dayName: map['dayName']?.toString() ?? "",
      room1EnergyKWh: parseD(map['room1EnergyKWh']),
      room2EnergyKWh: parseD(map['room2EnergyKWh']),
      totalEnergyKWh: parseD(map['totalEnergyKWh']),
      estimatedBill: parseD(map['estimatedBill']),
      readingsCount: map['readingsCount'] is int ? map['readingsCount'] : 0,
    );
  }
}

// =========================================================================
// 7. REAL-TIME ENERGY & COST METRICS MODEL
// =========================================================================
class RealEnergyMetrics {
  final double currentPower;          // Instantaneous Power (W)
  final bool isDeviceOn;               // True if currentPower > 5.0 W
  final String statusText;             // "● ON" or "OFF"
  final double todayEnergyKWh;         // Accumulated Energy Today (kWh)
  final double yesterdayEnergyKWh;     // Accumulated Energy Yesterday (kWh)
  final double thisWeekEnergyKWh;      // Accumulated Energy This Week / Last 7 Days (kWh)
  final double thisMonthEnergyKWh;     // Accumulated Energy This Month (kWh)
  final double tariffRate;             // Configurable Tariff (Rs/kWh)
  final double estimatedBill;          // Estimated Monthly Electricity Bill (Rs) = thisMonthEnergyKWh * tariffRate
  final double todayEstimatedBill;     // Estimated Today Electricity Bill (Rs) = todayEnergyKWh * tariffRate
  final int totalReadingsCount;        // Total historical records loaded
  final int todayReadingsCount;        // Records for today
  final int monthReadingsCount;        // Records for this month
  final DateTime lastUpdated;          // Timestamp of latest reading
  final List<EnergyReading> recentHistory; // Filtered chronological readings
  final List<DailyRoomEnergy> dailyBreakdown; // Historical room-wise daily energy records

  RealEnergyMetrics({
    required this.currentPower,
    required this.isDeviceOn,
    required this.statusText,
    required this.todayEnergyKWh,
    this.yesterdayEnergyKWh = 0.0,
    this.thisWeekEnergyKWh = 0.0,
    required this.thisMonthEnergyKWh,
    required this.tariffRate,
    required this.estimatedBill,
    this.todayEstimatedBill = 0.0,
    required this.totalReadingsCount,
    required this.todayReadingsCount,
    required this.monthReadingsCount,
    required this.lastUpdated,
    required this.recentHistory,
    this.dailyBreakdown = const [],
  });

  factory RealEnergyMetrics.empty({double tariffRate = 7.00}) {
    return RealEnergyMetrics(
      currentPower: 0.0,
      isDeviceOn: false,
      statusText: "OFF",
      todayEnergyKWh: 0.0,
      yesterdayEnergyKWh: 0.0,
      thisWeekEnergyKWh: 0.0,
      thisMonthEnergyKWh: 0.0,
      tariffRate: tariffRate,
      estimatedBill: 0.0,
      todayEstimatedBill: 0.0,
      totalReadingsCount: 0,
      todayReadingsCount: 0,
      monthReadingsCount: 0,
      lastUpdated: DateTime.now(),
      recentHistory: const [],
      dailyBreakdown: const [],
    );
  }
}

// =========================================================================
// 8. ACCURATE TIMESTAMP-BASED ENERGY CALCULATOR
// =========================================================================
class EnergyCalculator {
  /// Power threshold in Watts to determine ON/OFF state (avoids tiny sensor noise)
  static const double onOffPowerThreshold = 5.0;

  /// Helper to format a DateTime as YYYY-MM-DD
  static String formatDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')}";
  }

  /// Computes cumulative energy in kWh:
  /// - Uses cumulative hardware energy (latestTotalEnergy - firstTotalEnergyOfToday)
  ///   with reset/reboot safety across historical records.
  /// - Falls back to power trapezoidal integration when hardware totalEnergy is not present.
  static double computeEnergyKWh(List<EnergyReading> readings) {
    if (readings.length < 2) return 0.0;

    // Deduplicate and ensure strict chronological order
    final sorted = List<EnergyReading>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final cleanList = <EnergyReading>[];
    DateTime? prevTime;
    for (final r in sorted) {
      if (prevTime == null || r.timestamp.isAfter(prevTime)) {
        cleanList.add(r);
        prevTime = r.timestamp;
      }
    }

    if (cleanList.length < 2) return 0.0;

    // Check if readings contain hardware cumulative energy (totalEnergy > 0)
    final hasHwEnergy = cleanList.any((r) => r.totalEnergy > 0.0);
    if (hasHwEnergy) {
      double totalDelta = 0.0;
      for (int i = 1; i < cleanList.length; i++) {
        final prev = cleanList[i - 1].totalEnergy;
        final curr = cleanList[i].totalEnergy;
        if (curr >= prev) {
          totalDelta += (curr - prev);
        } else {
          // Hardware meter reboot/reset detected
          totalDelta += curr;
        }
      }
      return totalDelta.clamp(0.0, double.infinity);
    }

    // Fallback: trapezoidal power integration when hardware meter totalEnergy is 0
    double totalIntegratedWh = 0.0;
    for (int i = 1; i < cleanList.length; i++) {
      final prev = cleanList[i - 1];
      final curr = cleanList[i];
      final deltaSeconds = curr.timestamp.difference(prev.timestamp).inSeconds;
      if (deltaSeconds > 0 && deltaSeconds <= 86400) {
        final effectiveHours = deltaSeconds / 3600.0;
        final avgPowerW = (prev.totalPower + curr.totalPower) / 2.0;
        if (avgPowerW > 0.0) {
          totalIntegratedWh += avgPowerW * effectiveHours;
        }
      }
    }
    return (totalIntegratedWh / 1000.0).clamp(0.0, double.infinity);
  }

  /// Computes historical daily room-wise energy consumption by date (YYYY-MM-DD):
  /// - Groups readings by calendar date using Firebase timestamps.
  /// - Accurately attributes incremental transitions between consecutive readings to the target date.
  /// - For each date:
  ///     Room 1 daily kWh = cumulative energy delta for Room 1
  ///     Room 2 daily kWh = cumulative energy delta for Room 2
  ///     Total daily kWh = Room 1 daily kWh + Room 2 daily kWh
  ///     Daily bill = Total daily kWh * tariff rate
  /// - Preserves historical dates without overwriting past days.
  static List<DailyRoomEnergy> computeDailyRoomBreakdown(
    List<EnergyReading> readings, {
    double tariffRate = 7.00,
  }) {
    if (readings.isEmpty) return [];

    final valid = readings.where((r) => r.isValidTimestamp).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (valid.isEmpty) return [];

    // Maps to track energy deltas and counts per date string
    final Map<String, double> r1Map = {};
    final Map<String, double> r2Map = {};
    final Map<String, double> totMap = {};
    final Map<String, int> countMap = {};
    final Map<String, DateTime> sampleDateMap = {};

    final firstDateStr = formatDate(valid.first.timestamp);
    r1Map[firstDateStr] = 0.0;
    r2Map[firstDateStr] = 0.0;
    totMap[firstDateStr] = 0.0;
    countMap[firstDateStr] = 1;
    sampleDateMap[firstDateStr] = valid.first.timestamp;

    for (int i = 1; i < valid.length; i++) {
      final prev = valid[i - 1];
      final curr = valid[i];
      final dateStr = formatDate(curr.timestamp);

      r1Map.putIfAbsent(dateStr, () => 0.0);
      r2Map.putIfAbsent(dateStr, () => 0.0);
      totMap.putIfAbsent(dateStr, () => 0.0);
      countMap[dateStr] = (countMap[dateStr] ?? 0) + 1;
      sampleDateMap[dateStr] = curr.timestamp;

      // Room 1 delta
      double dE1 = 0.0;
      if (curr.energy1 > 0.0 || prev.energy1 > 0.0) {
        if (curr.energy1 >= prev.energy1) {
          dE1 = curr.energy1 - prev.energy1;
        } else {
          dE1 = curr.energy1; // meter reboot
        }
      } else {
        final dtSec = curr.timestamp.difference(prev.timestamp).inSeconds;
        if (dtSec > 0 && dtSec <= 86400) {
          final avgP = (prev.power1 + curr.power1) / 2.0;
          if (avgP > 0.0) {
            dE1 = avgP * (dtSec / 3600.0) / 1000.0;
          }
        }
      }

      // Room 2 delta
      double dE2 = 0.0;
      if (curr.energy2 > 0.0 || prev.energy2 > 0.0) {
        if (curr.energy2 >= prev.energy2) {
          dE2 = curr.energy2 - prev.energy2;
        } else {
          dE2 = curr.energy2; // meter reboot
        }
      } else {
        final dtSec = curr.timestamp.difference(prev.timestamp).inSeconds;
        if (dtSec > 0 && dtSec <= 86400) {
          final avgP = (prev.power2 + curr.power2) / 2.0;
          if (avgP > 0.0) {
            dE2 = avgP * (dtSec / 3600.0) / 1000.0;
          }
        }
      }

      // Total delta
      double dTot = 0.0;
      if (curr.totalEnergy > 0.0 || prev.totalEnergy > 0.0) {
        if (curr.totalEnergy >= prev.totalEnergy) {
          dTot = curr.totalEnergy - prev.totalEnergy;
        } else {
          dTot = curr.totalEnergy;
        }
      }
      if (dTot == 0.0 && (dE1 + dE2 > 0.0)) {
        dTot = dE1 + dE2;
      }

      r1Map[dateStr] = (r1Map[dateStr] ?? 0.0) + dE1;
      r2Map[dateStr] = (r2Map[dateStr] ?? 0.0) + dE2;
      totMap[dateStr] = (totMap[dateStr] ?? 0.0) + dTot;
    }

    const weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final sortedDates = r1Map.keys.toList()..sort();
    final List<DailyRoomEnergy> result = [];

    for (final dateKey in sortedDates) {
      final sampleDate = sampleDateMap[dateKey] ?? DateTime.now();
      final dayOfWeek = sampleDate.weekday;
      final dayName = (dayOfWeek >= 1 && dayOfWeek <= 7) ? weekdayNames[dayOfWeek - 1] : "";
      final r1 = (r1Map[dateKey] ?? 0.0).clamp(0.0, double.infinity);
      final r2 = (r2Map[dateKey] ?? 0.0).clamp(0.0, double.infinity);
      final tot = (totMap[dateKey] ?? (r1 + r2)).clamp(0.0, double.infinity);
      final bill = (tot * tariffRate).clamp(0.0, double.infinity);

      result.add(DailyRoomEnergy(
        date: dateKey,
        dayName: dayName,
        room1EnergyKWh: r1,
        room2EnergyKWh: r2,
        totalEnergyKWh: tot,
        estimatedBill: bill,
        readingsCount: countMap[dateKey] ?? 0,
      ));
    }

    return result;
  }

  /// Calculates complete real-time energy metrics from live & historical telemetry
  static RealEnergyMetrics calculateMetrics({
    required EnergyReading? latest,
    required List<EnergyReading> history,
    double tariffRate = 7.00,
    double powerThreshold = onOffPowerThreshold,
  }) {
    if (latest == null && history.isEmpty) {
      return RealEnergyMetrics.empty(tariffRate: tariffRate);
    }

    // Combine history with latest reading if not already included
    final allReadings = List<EnergyReading>.from(history);
    if (latest != null && !allReadings.any((r) => r.key == latest.key || r.timestamp == latest.timestamp)) {
      allReadings.add(latest);
    }

    allReadings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final effectiveLatest = latest ?? (allReadings.isNotEmpty ? allReadings.last : null);
    final double currentPower = (effectiveLatest?.totalPower ?? 0.0).clamp(0.0, double.infinity);
    final bool isDeviceOn = currentPower > powerThreshold;
    final String statusText = isDeviceOn ? "● ON" : "OFF";
    final DateTime refTime = effectiveLatest?.timestamp ?? DateTime.now();

    final todayStr = formatDate(refTime);
    final yesterdayStr = formatDate(refTime.subtract(const Duration(days: 1)));
    final monthPrefix = "${refTime.year.toString().padLeft(4, '0')}-${refTime.month.toString().padLeft(2, '0')}";

    // Compute complete historical daily room breakdown
    final dailyBreakdown = computeDailyRoomBreakdown(allReadings, tariffRate: tariffRate);

    // Today's energy from daily breakdown
    double todayKWh = 0.0;
    int todayReadings = 0;
    for (final d in dailyBreakdown) {
      if (d.date == todayStr) {
        todayKWh = d.totalEnergyKWh;
        todayReadings = d.readingsCount;
        break;
      }
    }

    // Yesterday's energy from daily breakdown
    double yesterdayKWh = 0.0;
    for (final d in dailyBreakdown) {
      if (d.date == yesterdayStr) {
        yesterdayKWh = d.totalEnergyKWh;
        break;
      }
    }

    // This week (last 7 days window up to refTime)
    final sevenDaysAgo = refTime.subtract(const Duration(days: 6));
    final sevenDaysAgoStr = formatDate(DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day));
    double thisWeekKWh = 0.0;
    for (final d in dailyBreakdown) {
      if (d.date.compareTo(sevenDaysAgoStr) >= 0 && d.date.compareTo(todayStr) <= 0) {
        thisWeekKWh += d.totalEnergyKWh;
      }
    }

    // This month's energy (all dates in current month)
    double monthKWh = 0.0;
    int monthReadings = 0;
    for (final d in dailyBreakdown) {
      if (d.date.startsWith(monthPrefix)) {
        monthKWh += d.totalEnergyKWh;
        monthReadings += d.readingsCount;
      }
    }

    // Fallbacks if data belongs to a single recording session
    if (monthKWh == 0.0 && dailyBreakdown.isNotEmpty) {
      for (final d in dailyBreakdown) {
        monthKWh += d.totalEnergyKWh;
        monthReadings += d.readingsCount;
      }
    }
    if (todayKWh == 0.0 && dailyBreakdown.length == 1) {
      todayKWh = dailyBreakdown.first.totalEnergyKWh;
    }
    if (thisWeekKWh == 0.0 && monthKWh > 0.0) {
      thisWeekKWh = monthKWh;
    }

    // Estimated monthly bill = thisMonthEnergyKWh * tariffRate
    final double estimatedMonthlyBill = monthKWh * tariffRate;
    // Estimated today's bill = todayEnergyKWh * tariffRate
    final double todayBill = todayKWh * tariffRate;

    return RealEnergyMetrics(
      currentPower: currentPower,
      isDeviceOn: isDeviceOn,
      statusText: statusText,
      todayEnergyKWh: todayKWh,
      yesterdayEnergyKWh: yesterdayKWh,
      thisWeekEnergyKWh: thisWeekKWh,
      thisMonthEnergyKWh: monthKWh,
      tariffRate: tariffRate,
      estimatedBill: estimatedMonthlyBill,
      todayEstimatedBill: todayBill,
      totalReadingsCount: allReadings.length,
      todayReadingsCount: todayReadings > 0 ? todayReadings : allReadings.length,
      monthReadingsCount: monthReadings > 0 ? monthReadings : allReadings.length,
      lastUpdated: refTime,
      recentHistory: allReadings.length > 50 ? allReadings.sublist(allReadings.length - 50) : allReadings,
      dailyBreakdown: dailyBreakdown,
    );
  }
}

