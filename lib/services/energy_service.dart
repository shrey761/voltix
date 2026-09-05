import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/energy_models.dart';

class EnergyService {
  static final EnergyService _instance = EnergyService._internal();
  factory EnergyService() => _instance;
  EnergyService._internal();

  static final DatabaseReference _rootRef =
      FirebaseDatabase.instance.ref().child('sensor_logs').child('esp32_01');

  static final DatabaseReference readingsRef = _rootRef.child('readings');
  static final DatabaseReference predictionsRef = _rootRef.child('predictions').child('latest');
  static final DatabaseReference analyticsRef = _rootRef.child('analytics').child('latest');
  static final DatabaseReference optimizationRef = _rootRef.child('optimization').child('latest');
  static final DatabaseReference notificationsRef = _rootRef.child('notifications').child('latest');
  static final DatabaseReference alertsRef = _rootRef.child('alerts').child('latest');

  // =========================================================================
  // STREAMS
  // =========================================================================

  /// Stream of the single latest EnergyReading from Firebase
  Stream<EnergyReading?> get latestReadingStream {
    return readingsRef.orderByKey().limitToLast(1).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      final map = Map<dynamic, dynamic>.from(raw);
      if (map.isEmpty) return null;
      final firstKey = map.keys.first.toString();
      final readingRaw = map[firstKey];
      if (readingRaw is! Map) return null;
      return EnergyReading.fromMap(firstKey, Map<dynamic, dynamic>.from(readingRaw));
    });
  }

  /// Stream of recent historical readings for chart & delta calculations
  Stream<List<EnergyReading>> get recentReadingsStream {
    return readingsRef.orderByKey().limitToLast(100).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return [];
      final map = Map<dynamic, dynamic>.from(raw);
      final List<EnergyReading> list = [];
      map.forEach((k, v) {
        if (v is Map) {
          list.add(EnergyReading.fromMap(k.toString(), Map<dynamic, dynamic>.from(v)));
        }
      });
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// Stream of real-time Random Forest predictions from Firebase
  Stream<PredictionResult?> get predictionsStream {
    return predictionsRef.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      return PredictionResult.fromMap(Map<dynamic, dynamic>.from(raw));
    });
  }

  /// Stream of analytics & Gruha Jyothi forecast from Firebase
  Stream<AnalyticsData?> get analyticsStream {
    return analyticsRef.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      return AnalyticsData.fromMap(Map<dynamic, dynamic>.from(raw));
    });
  }

  /// Stream of monthly statistical forecast from Firebase
  Stream<MonthlyForecast?> get monthlyForecastStream {
    return analyticsRef.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      return MonthlyForecast.fromMap(Map<dynamic, dynamic>.from(raw));
    });
  }

  /// Stream of optimization insights & savings potential from Firebase
  Stream<OptimizationInsight?> get optimizationStream {
    return optimizationRef.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      return OptimizationInsight.fromMap(Map<dynamic, dynamic>.from(raw));
    });
  }

  /// Stream of active dynamic notifications & alerts from Firebase
  Stream<List<EnergyNotification>> get notificationsStream {
    return notificationsRef.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return [];
      final map = Map<dynamic, dynamic>.from(raw);
      final items = map['items'];
      if (items is! List) return [];
      final List<EnergyNotification> list = [];
      for (var item in items) {
        if (item is Map) {
          list.add(EnergyNotification.fromMap(Map<dynamic, dynamic>.from(item)));
        }
      }
      return list;
    });
  }

  /// Alias stream for alerts
  Stream<List<EnergyNotification>> get alertsStream => notificationsStream;

  // =========================================================================
  // DETERMINISTIC CLIENT-SIDE COMPUTATION FALLBACKS
  // =========================================================================

  static double _computeDeltaSafe(List<EnergyReading> list, double latestVal) {
    if (list.isEmpty) return latestVal.clamp(0.0, double.infinity);
    double total = 0.0;
    for (int i = 1; i < list.length; i++) {
      final diff = list[i].totalEnergy - list[i - 1].totalEnergy;
      if (diff >= 0) {
        total += diff;
      } else {
        total += list[i].totalEnergy; // Rollover detected
      }
    }
    final lastDiff = latestVal - list.last.totalEnergy;
    if (lastDiff >= 0) {
      total += lastDiff;
    } else {
      total += latestVal;
    }
    return total.clamp(0.0, double.infinity);
  }

  /// Computes monthly forecast from readings list if backend bridge is offline
  static MonthlyForecast computeForecastFromReadings(
    EnergyReading? latest,
    List<EnergyReading> history,
  ) {
    const double allocated = 96.0;
    if (latest == null) {
      return MonthlyForecast(
        monthToDateUnits: 0.0,
        todayUnits: 0.0,
        weekUnits: 0.0,
        averageDailyUnits: 0.0,
        projectedMonthEndUnits: 0.0,
        allocatedUnits: allocated,
        remainingUnits: allocated,
        projectedExcessUnits: 0.0,
        usagePercentage: 0.0,
        daysElapsed: DateTime.now().day,
        daysInMonth: 30,
      );
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final mList = history.where((r) => r.timestamp.isAfter(startOfMonth) || r.timestamp.isAtSameMomentAs(startOfMonth)).toList();
    final tList = history.where((r) => r.timestamp.isAfter(startOfToday) || r.timestamp.isAtSameMomentAs(startOfToday)).toList();
    final wList = history.where((r) => r.timestamp.isAfter(startOfWeek) || r.timestamp.isAtSameMomentAs(startOfWeek)).toList();

    final double monthToDate = _computeDeltaSafe(mList, latest.totalEnergy);
    final double todayUnits = _computeDeltaSafe(tList, latest.totalEnergy);
    final double weekUnits = _computeDeltaSafe(wList, latest.totalEnergy);

    final int daysElapsed = now.day > 0 ? now.day : 1;
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    final double avgDaily = monthToDate / daysElapsed;
    final double projectedEnd = avgDaily * daysInMonth;
    final double remaining = (allocated - monthToDate).clamp(0.0, allocated);
    final double projectedExcess = (projectedEnd - allocated).clamp(0.0, double.infinity);
    final double pct = (monthToDate / allocated).clamp(0.0, 1.0);

    return MonthlyForecast(
      monthToDateUnits: monthToDate,
      todayUnits: todayUnits,
      weekUnits: weekUnits,
      averageDailyUnits: avgDaily,
      projectedMonthEndUnits: projectedEnd,
      allocatedUnits: allocated,
      remainingUnits: remaining,
      projectedExcessUnits: projectedExcess,
      usagePercentage: pct,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
    );
  }
}
