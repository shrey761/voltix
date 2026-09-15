import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/energy_models.dart';
import 'tariff_service.dart';

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

  final TariffService tariffService = TariffService();

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

  /// Stream of recent historical readings for chart & energy accumulation (up to 1000 records)
  Stream<List<EnergyReading>> get recentReadingsStream {
    return readingsRef.orderByKey().limitToLast(1000).onValue.map((event) {
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

  /// Combined stream calculating RealEnergyMetrics dynamically from live telemetry
  Stream<RealEnergyMetrics> get realMetricsStream {
    return recentReadingsStream.map((history) {
      final latest = history.isNotEmpty ? history.last : null;
      return EnergyCalculator.calculateMetrics(
        latest: latest,
        history: history,
        tariffRate: tariffService.tariffRate,
      );
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

  /// Computes monthly forecast from readings list using EnergyCalculator
  static MonthlyForecast computeForecastFromReadings(
    EnergyReading? latest,
    List<EnergyReading> history, {
    double allocated = 96.0,
  }) {
    if (latest == null && history.isEmpty) {
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

    final refTime = latest?.timestamp ?? (history.isNotEmpty ? history.last.timestamp : DateTime.now());
    final startOfMonth = DateTime(refTime.year, refTime.month, 1);
    final startOfToday = DateTime(refTime.year, refTime.month, refTime.day);
    final startOfWeek = refTime.subtract(Duration(days: refTime.weekday - 1));

    final allReadings = List<EnergyReading>.from(history);
    if (latest != null && !allReadings.any((r) => r.key == latest.key)) {
      allReadings.add(latest);
    }
    allReadings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final mList = allReadings.where((r) => r.timestamp.isAfter(startOfMonth) || r.timestamp.isAtSameMomentAs(startOfMonth)).toList();
    final tList = allReadings.where((r) => r.timestamp.isAfter(startOfToday) || r.timestamp.isAtSameMomentAs(startOfToday)).toList();
    final wList = allReadings.where((r) => r.timestamp.isAfter(startOfWeek) || r.timestamp.isAtSameMomentAs(startOfWeek)).toList();

    double monthToDate = EnergyCalculator.computeEnergyKWh(mList);
    double todayUnits = EnergyCalculator.computeEnergyKWh(tList);
    double weekUnits = EnergyCalculator.computeEnergyKWh(wList);

    if (monthToDate == 0.0 && allReadings.length >= 2) {
      monthToDate = EnergyCalculator.computeEnergyKWh(allReadings);
    }
    if (todayUnits == 0.0 && monthToDate > 0.0) {
      todayUnits = monthToDate;
    }
    if (weekUnits == 0.0 && monthToDate > 0.0) {
      weekUnits = monthToDate;
    }

    final int daysElapsed = refTime.day > 0 ? refTime.day : 1;
    final int daysInMonth = DateTime(refTime.year, refTime.month + 1, 0).day;

    final double avgDaily = monthToDate / daysElapsed;
    final double projectedEnd = avgDaily * daysInMonth;
    final double remaining = (allocated - monthToDate).clamp(0.0, allocated);
    final double projectedExcess = (projectedEnd - allocated).clamp(0.0, double.infinity);
    final double pct = (allocated > 0) ? (monthToDate / allocated).clamp(0.0, 1.0) : 0.0;

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

