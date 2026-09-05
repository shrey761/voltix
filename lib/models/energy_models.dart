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

  factory EnergyReading.fromMap(String key, Map<dynamic, dynamic> map) {
    DateTime ts;
    final dynamic tsVal = map['timestamp'];
    if (tsVal is String) {
      ts = DateTime.tryParse(tsVal) ?? DateTime.now();
    } else {
      ts = DateTime.now();
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
      nextHourConfidence: nextConf > 0.0 ? nextConf : 95.0,
      tomorrowState: tmrwMap['state']?.toString() ?? "NORMAL",
      tomorrowConfidence: tmrwConf > 0.0 ? tmrwConf : 90.0,
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
