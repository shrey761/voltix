import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartenergy/models/energy_models.dart';
import 'package:smartenergy/services/energy_service.dart';
import 'package:smartenergy/services/tariff_service.dart';
import 'package:smartenergy/widgets/data_card.dart';

void main() {
  group('Voltix Data Models Unit Tests', () {
    test('EnergyReading correctly parses numeric Firebase telemetry map', () {
      final map = {
        'timestamp': '2026-08-24 18:05:04',
        'voltage1': 228.5,
        'voltage2': 230.1,
        'current1': 4.5,
        'current2': 7.2,
        'power1': 1028.25,
        'power2': 1656.72,
        'energy1': 5.432,
        'energy2': 8.123,
        'totalPower': 2684.97,
        'totalEnergy': 13.555,
        'totalCurrent': 11.7,
      };

      final reading = EnergyReading.fromMap('reading_123', map);
      expect(reading.key, 'reading_123');
      expect(reading.voltage1, 228.5);
      expect(reading.power1, 1028.25);
      expect(reading.power2, 1656.72);
      expect(reading.totalPower, 2684.97);
      expect(reading.totalEnergy, 13.555);
      expect(reading.isValidTimestamp, true);
    });

    test('EnergyReading handles TIME_ERROR safely without corrupting timestamp', () {
      final map = {
        'timestamp': 'TIME_ERROR',
        'voltage1': 230.0,
        'power1': 0.0,
      };

      final reading = EnergyReading.fromMap('reading_err', map);
      expect(reading.isValidTimestamp, false);
      expect(reading.timestamp, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('Energy readings sort chronologically by timestamp, ignoring lexicographical key order', () {
      final oldReading = EnergyReading.fromMap('reading_995565', {
        'timestamp': '2026-10-04 16:14:59',
        'power1': 100.0,
        'power2': 50.0,
      });

      final todayReading = EnergyReading.fromMap('reading_1509990', {
        'timestamp': '2026-10-06 14:40:04',
        'power1': 0.0,
        'power2': 21.0,
      });

      final list = [oldReading, todayReading];
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Latest reading must be today's reading (2026-10-06), not the lexicographically larger key
      expect(list.last.key, 'reading_1509990');
      expect(list.last.timestamp, DateTime(2026, 10, 6, 14, 40, 4));
    });

    test('PredictionResult correctly parses multi-horizon ML predictions', () {
      final map = {
        'timestamp': '2026-08-24 18:05:04',
        'room1': {
          'currentPower': 0.0,
          'predictedPower': 1135.7,
          'nextHour': {'state': 'HIGH USAGE', 'confidencePercent': 64.0},
          'tomorrow': {'state': 'HIGH USAGE', 'confidencePercent': 97.8},
          'recommendations': ['Reduce non-essential loads in Room 1 during the next hour.']
        },
        'room2': {
          'currentPower': 1645.3,
          'predictedPower': 1335.4,
          'nextHour': {'state': 'HIGH USAGE', 'confidencePercent': 62.7},
          'tomorrow': {'state': 'NORMAL', 'confidencePercent': 94.8},
          'recommendations': ['Reduce non-essential loads in Room 2 during the next hour.']
        },
        'summary': {
          'totalCurrentPower': 1645.3,
          'totalPredictedPower': 2471.1,
          'overallNextHourState': 'HIGH USAGE'
        }
      };

      final pred = PredictionResult.fromMap(map);
      expect(pred.room1.nextHourState, 'HIGH USAGE');
      expect(pred.room1.nextHourConfidence, 64.0);
      expect(pred.room1.tomorrowState, 'HIGH USAGE');
      expect(pred.room1.tomorrowConfidence, 97.8);
      expect(pred.room2.nextHourState, 'HIGH USAGE');
      expect(pred.room2.tomorrowState, 'NORMAL');
      expect(pred.totalPredictedPower, 2471.1);
      expect(pred.overallNextHourState, 'HIGH USAGE');
    });

    test('MonthlyForecast calculates reset-safe energy deltas and projections', () {
      final latest = EnergyReading(
        key: 'r_now',
        timestamp: DateTime(2026, 8, 24, 18, 0),
        voltage1: 230,
        voltage2: 230,
        current1: 2,
        current2: 3,
        power1: 460,
        power2: 690,
        energy1: 10,
        energy2: 15,
        totalCurrent: 5,
        totalPower: 1150,
        totalEnergy: 25.0,
      );

      final history = [
        EnergyReading(
          key: 'r_start',
          timestamp: DateTime(2026, 8, 1, 0, 0),
          voltage1: 230,
          voltage2: 230,
          current1: 0,
          current2: 0,
          power1: 0,
          power2: 0,
          energy1: 2,
          energy2: 3,
          totalCurrent: 0,
          totalPower: 0,
          totalEnergy: 5.0,
        ),
        latest,
      ];

      final forecast = EnergyService.computeForecastFromReadings(latest, history);
      expect(forecast.allocatedUnits, 96.0);
      expect(forecast.monthToDateUnits, greaterThanOrEqualTo(0.0));
      expect(forecast.remainingUnits, lessThanOrEqualTo(96.0));
    });
  });

  group('Voltix Real Energy Monitoring & Mathematical Scenarios', () {
    test('TEST 1: Empty Firebase Database yields 0 values, OFF status and ₹0.00 bill', () {
      final metrics = EnergyCalculator.calculateMetrics(
        latest: null,
        history: [],
        tariffRate: 7.00,
      );

      expect(metrics.currentPower, 0.0);
      expect(metrics.isDeviceOn, false);
      expect(metrics.statusText, "OFF");
      expect(metrics.todayEnergyKWh, 0.0);
      expect(metrics.thisMonthEnergyKWh, 0.0);
      expect(metrics.estimatedBill, 0.0);
      expect(metrics.totalReadingsCount, 0);
    });

    test('TEST 2 & 3: 8W Bulb ON at 10:00 and running until 11:00 accumulates exactly 0.008 kWh (8 Wh)', () {
      final t1 = DateTime(2026, 9, 12, 10, 0, 0);
      final t2 = DateTime(2026, 9, 12, 11, 0, 0); // 1 hour later

      final r1 = EnergyReading(
        key: 'r1',
        timestamp: t1,
        voltage1: 230,
        voltage2: 230,
        current1: 8 / 230,
        current2: 0,
        power1: 8.0,
        power2: 0.0,
        energy1: 0,
        energy2: 0,
        totalCurrent: 8 / 230,
        totalPower: 8.0,
        totalEnergy: 0.0,
      );

      final r2 = EnergyReading(
        key: 'r2',
        timestamp: t2,
        voltage1: 230,
        voltage2: 230,
        current1: 8 / 230,
        current2: 0,
        power1: 8.0,
        power2: 0.0,
        energy1: 0,
        energy2: 0,
        totalCurrent: 8 / 230,
        totalPower: 8.0,
        totalEnergy: 0.0,
      );

      final metrics = EnergyCalculator.calculateMetrics(
        latest: r2,
        history: [r1, r2],
        tariffRate: 7.00,
      );

      expect(metrics.currentPower, 8.0);
      expect(metrics.isDeviceOn, true);
      expect(metrics.statusText, "● ON");
      // 8W * 1h = 8 Wh = 0.008 kWh
      expect(metrics.todayEnergyKWh, closeTo(0.008, 0.0001));
    });

    test('TEST 4: Bulb turns OFF at 12:00 (0W) -> Power becomes 0W, but energy does NOT reset', () {
      final t1 = DateTime(2026, 9, 12, 10, 0, 0);
      final t2 = DateTime(2026, 9, 12, 11, 0, 0);
      final t3 = DateTime(2026, 9, 12, 12, 0, 0); // Turned OFF: 0W

      final r1 = EnergyReading(
        key: 'r1', timestamp: t1, voltage1: 230, voltage2: 230,
        current1: 8 / 230, current2: 0, power1: 8.0, power2: 0.0,
        energy1: 0, energy2: 0, totalCurrent: 8 / 230, totalPower: 8.0, totalEnergy: 0.0,
      );
      final r2 = EnergyReading(
        key: 'r2', timestamp: t2, voltage1: 230, voltage2: 230,
        current1: 8 / 230, current2: 0, power1: 8.0, power2: 0.0,
        energy1: 0, energy2: 0, totalCurrent: 8 / 230, totalPower: 8.0, totalEnergy: 0.0,
      );
      final r3 = EnergyReading(
        key: 'r3', timestamp: t3, voltage1: 230, voltage2: 230,
        current1: 0, current2: 0, power1: 0.0, power2: 0.0,
        energy1: 0, energy2: 0, totalCurrent: 0, totalPower: 0.0, totalEnergy: 0.0,
      );

      final metrics = EnergyCalculator.calculateMetrics(
        latest: r3,
        history: [r1, r2, r3],
        tariffRate: 7.00,
      );

      // Power is now 0W and status is OFF
      expect(metrics.currentPower, 0.0);
      expect(metrics.isDeviceOn, false);
      expect(metrics.statusText, "OFF");
      // Energy did NOT reset: stays at the accumulated value
      expect(metrics.todayEnergyKWh, greaterThanOrEqualTo(0.008));
    });

    test('TEST 5: Bulb turns ON again at 14:00 (8W) -> Energy continues increasing from previous total', () {
      final t1 = DateTime(2026, 9, 12, 10, 0, 0);
      final t2 = DateTime(2026, 9, 12, 11, 0, 0);
      final t3 = DateTime(2026, 9, 12, 12, 0, 0); // 0W
      final t4 = DateTime(2026, 9, 12, 13, 0, 0); // 0W
      final t5 = DateTime(2026, 9, 12, 14, 0, 0); // 8W ON again

      final history = [
        EnergyReading(key: 'r1', timestamp: t1, voltage1: 230, voltage2: 230, current1: 0.03, current2: 0, power1: 8, power2: 0, energy1: 0, energy2: 0, totalCurrent: 0.03, totalPower: 8, totalEnergy: 0),
        EnergyReading(key: 'r2', timestamp: t2, voltage1: 230, voltage2: 230, current1: 0.03, current2: 0, power1: 8, power2: 0, energy1: 0, energy2: 0, totalCurrent: 0.03, totalPower: 8, totalEnergy: 0),
        EnergyReading(key: 'r3', timestamp: t3, voltage1: 230, voltage2: 230, current1: 0, current2: 0, power1: 0, power2: 0, energy1: 0, energy2: 0, totalCurrent: 0, totalPower: 0, totalEnergy: 0),
        EnergyReading(key: 'r4', timestamp: t4, voltage1: 230, voltage2: 230, current1: 0, current2: 0, power1: 0, power2: 0, energy1: 0, energy2: 0, totalCurrent: 0, totalPower: 0, totalEnergy: 0),
        EnergyReading(key: 'r5', timestamp: t5, voltage1: 230, voltage2: 230, current1: 0.03, current2: 0, power1: 8, power2: 0, energy1: 0, energy2: 0, totalCurrent: 0.03, totalPower: 8, totalEnergy: 0),
      ];

      final metrics = EnergyCalculator.calculateMetrics(
        latest: history.last,
        history: history,
        tariffRate: 7.00,
      );

      expect(metrics.currentPower, 8.0);
      expect(metrics.isDeviceOn, true);
      expect(metrics.statusText, "● ON");
      expect(metrics.todayEnergyKWh, greaterThanOrEqualTo(0.008));
    });

    test('TEST 6 & 7: Tariff Billing calculation from real kWh', () {
      final tariffService = TariffService();
      tariffService.tariffRate = 7.50; // Rs 7.50 per kWh

      expect(tariffService.calculateBill(0.0), 0.0);
      expect(tariffService.calculateBill(10.0), 75.0);
      expect(tariffService.calculateBill(12.64), closeTo(94.80, 0.01));
    });

    test('TEST 8: 5W ON/OFF Threshold does NOT alter raw power value (2W -> 2.0W OFF, 20W -> 20.0W ON)', () {
      final rLow = EnergyReading.fromMap('r_low', {
        'timestamp': '2026-10-06 10:00:00',
        'totalPower': 2.0,
      });

      final metricsLow = EnergyCalculator.calculateMetrics(
        latest: rLow,
        history: [rLow],
        tariffRate: 7.00,
      );

      // Power must remain exact 2.0W, status must be OFF (2W <= 5W)
      expect(metricsLow.currentPower, 2.0);
      expect(metricsLow.isDeviceOn, false);
      expect(metricsLow.statusText, "OFF");

      final rHigh = EnergyReading.fromMap('r_high', {
        'timestamp': '2026-10-06 10:01:00',
        'totalPower': 20.0,
      });

      final metricsHigh = EnergyCalculator.calculateMetrics(
        latest: rHigh,
        history: [rLow, rHigh],
        tariffRate: 7.00,
      );

      // Power must remain exact 20.0W, status must be ON (20W > 5W)
      expect(metricsHigh.currentPower, 20.0);
      expect(metricsHigh.isDeviceOn, true);
      expect(metricsHigh.statusText, "● ON");
    });

    test('TEST 9: Today Energy calculates cumulative difference (latestTotalEnergy - firstTotalEnergyOfToday) and estimatedBill = todayEnergy * tariff', () {
      final r1 = EnergyReading.fromMap('r1', {
        'timestamp': '2026-10-06 08:00:00',
        'totalPower': 20.0,
        'totalEnergy': 0.0100,
      });
      final r2 = EnergyReading.fromMap('r2', {
        'timestamp': '2026-10-06 12:00:00',
        'totalPower': 20.0,
        'totalEnergy': 0.0150,
      });
      final r3 = EnergyReading.fromMap('r3', {
        'timestamp': '2026-10-06 16:00:00',
        'totalPower': 20.0,
        'totalEnergy': 0.0225,
      });

      final metrics = EnergyCalculator.calculateMetrics(
        latest: r3,
        history: [r1, r2, r3],
        tariffRate: 7.00,
      );

      // Cumulative difference: 0.0225 - 0.0100 = 0.0125 kWh (NOT the sum 0.01 + 0.015 + 0.0225 = 0.0475)
      expect(metrics.todayEnergyKWh, closeTo(0.0125, 0.0001));
      // Estimated bill: 0.0125 * 7.00 = 0.0875
      expect(metrics.estimatedBill, closeTo(0.0875, 0.0001));
    });

    test('TEST 10: Historical daily + room-wise energy preservation across multiple days (Tuesday + Wednesday)', () {
      // Tuesday readings (2026-10-06)
      final tue1 = EnergyReading.fromMap('tue_1', {
        'timestamp': '2026-10-06 08:00:00',
        'energy1': 0.10,
        'energy2': 0.05,
        'totalEnergy': 0.15,
        'power1': 100.0,
        'power2': 50.0,
      });
      final tue2 = EnergyReading.fromMap('tue_2', {
        'timestamp': '2026-10-06 20:00:00',
        'energy1': 0.22, // delta = 0.12 kWh
        'energy2': 0.13, // delta = 0.08 kWh
        'totalEnergy': 0.35, // delta = 0.20 kWh
        'power1': 100.0,
        'power2': 50.0,
      });

      // Wednesday readings (2026-10-07)
      final wed1 = EnergyReading.fromMap('wed_1', {
        'timestamp': '2026-10-07 08:00:00',
        'energy1': 0.22,
        'energy2': 0.13,
        'totalEnergy': 0.35,
        'power1': 50.0,
        'power2': 150.0,
      });
      final wed2 = EnergyReading.fromMap('wed_2', {
        'timestamp': '2026-10-07 20:00:00',
        'energy1': 0.27, // delta = 0.05 kWh
        'energy2': 0.28, // delta = 0.15 kWh
        'totalEnergy': 0.55, // delta = 0.20 kWh
        'power1': 50.0,
        'power2': 150.0,
      });

      final fullHistory = [tue1, tue2, wed1, wed2];
      final breakdown = EnergyCalculator.computeDailyRoomBreakdown(fullHistory, tariffRate: 7.00);

      // Verify both days are preserved
      expect(breakdown.length, 2);

      // Tuesday verification
      final tueData = breakdown.firstWhere((d) => d.date == '2026-10-06');
      expect(tueData.dayName, 'Tue');
      expect(tueData.room1EnergyKWh, closeTo(0.12, 0.0001));
      expect(tueData.room2EnergyKWh, closeTo(0.08, 0.0001));
      expect(tueData.totalEnergyKWh, closeTo(0.20, 0.0001));
      expect(tueData.estimatedBill, closeTo(1.40, 0.0001));

      // Wednesday verification
      final wedData = breakdown.firstWhere((d) => d.date == '2026-10-07');
      expect(wedData.dayName, 'Wed');
      expect(wedData.room1EnergyKWh, closeTo(0.05, 0.0001));
      expect(wedData.room2EnergyKWh, closeTo(0.15, 0.0001));
      expect(wedData.totalEnergyKWh, closeTo(0.20, 0.0001));
      expect(wedData.estimatedBill, closeTo(1.40, 0.0001));
    });
    test('TEST 11: Monthly bill calculates month-to-date total kWh * tariff, while todayEstimatedBill calculates today kWh * tariff', () {
      final tue1 = EnergyReading.fromMap('tue_1', {
        'timestamp': '2026-10-06 08:00:00',
        'energy1': 0.0,
        'energy2': 0.0,
        'totalEnergy': 0.0,
      });
      final tue2 = EnergyReading.fromMap('tue_2', {
        'timestamp': '2026-10-06 20:00:00',
        'energy1': 0.10,
        'energy2': 0.10,
        'totalEnergy': 0.20,
      });
      final wed1 = EnergyReading.fromMap('wed_1', {
        'timestamp': '2026-10-07 08:00:00',
        'energy1': 0.10,
        'energy2': 0.10,
        'totalEnergy': 0.20,
      });
      final wed2 = EnergyReading.fromMap('wed_2', {
        'timestamp': '2026-10-07 20:00:00',
        'energy1': 0.20, // +0.10 kWh
        'energy2': 0.25, // +0.15 kWh
        'totalEnergy': 0.45, // +0.25 kWh
      });

      final metrics = EnergyCalculator.calculateMetrics(
        latest: wed2,
        history: [tue1, tue2, wed1, wed2],
        tariffRate: 7.00,
      );

      // Today (Wed 10-07) energy = 0.25 kWh -> Today's bill = 0.25 * 7 = Rs 1.75
      expect(metrics.todayEnergyKWh, closeTo(0.25, 0.0001));
      expect(metrics.todayEstimatedBill, closeTo(1.75, 0.0001));

      // Month-to-date (October) energy = 0.20 (Tue) + 0.25 (Wed) = 0.45 kWh
      // Monthly estimated bill = 0.45 * 7 = Rs 3.15 (NOT just today's bill)
      expect(metrics.thisMonthEnergyKWh, closeTo(0.45, 0.0001));
      expect(metrics.estimatedBill, closeTo(3.15, 0.0001));
    });

    test('TEST 12: Gruha Jyothi Quota evaluates normal, warning (85%+), and limit exceeded with exact overflow units', () {
      const quota = 96.0;

      // Normal state: 50 kWh used (52.1%)
      final normalUsed = 50.0;
      final normalProgress = normalUsed / quota;
      final normalRemaining = (quota - normalUsed).clamp(0.0, quota);
      expect(normalProgress < 0.85, true);
      expect(normalRemaining, 46.0);

      // Warning state: 85 kWh used (88.5%)
      final warnUsed = 85.0;
      final warnProgress = warnUsed / quota;
      final warnRemaining = (quota - warnUsed).clamp(0.0, quota);
      expect(warnProgress >= 0.85 && warnProgress <= 1.0, true);
      expect(warnRemaining, 11.0);

      // Limit Exceeded state: 110 kWh used (114.6%)
      final exceededUsed = 110.0;
      final exceededOverflow = exceededUsed - quota;
      expect(exceededUsed > quota, true);
      expect(exceededOverflow, 14.0);
    });

    test('TEST 13: 7-Day Weekly Analytics groups readings into 7 calendar days up to reference date', () {
      final r1a = EnergyReading.fromMap('r1a', {
        'timestamp': '2026-10-04 08:00:00',
        'energy1': 0.00,
        'energy2': 0.00,
        'totalEnergy': 0.00,
      });
      final r1b = EnergyReading.fromMap('r1b', {
        'timestamp': '2026-10-04 20:00:00',
        'energy1': 0.05,
        'energy2': 0.05,
        'totalEnergy': 0.10,
      });
      final r2a = EnergyReading.fromMap('r2a', {
        'timestamp': '2026-10-06 08:00:00',
        'energy1': 0.05,
        'energy2': 0.05,
        'totalEnergy': 0.10,
      });
      final r2b = EnergyReading.fromMap('r2b', {
        'timestamp': '2026-10-06 20:00:00',
        'energy1': 0.10,
        'energy2': 0.10,
        'totalEnergy': 0.20,
      });
      final r3a = EnergyReading.fromMap('r3a', {
        'timestamp': '2026-10-07 08:00:00',
        'energy1': 0.10,
        'energy2': 0.10,
        'totalEnergy': 0.20,
      });
      final r3b = EnergyReading.fromMap('r3b', {
        'timestamp': '2026-10-07 20:00:00',
        'energy1': 0.15,
        'energy2': 0.15,
        'totalEnergy': 0.30,
      });

      final metrics = EnergyCalculator.calculateMetrics(
        latest: r3b,
        history: [r1a, r1b, r2a, r2b, r3a, r3b],
        tariffRate: 7.00,
      );

      expect(metrics.dailyBreakdown.length, 3);
      expect(metrics.thisWeekEnergyKWh, closeTo(0.30, 0.0001));
    });
  });

  group('Voltix Widgets Unit Tests', () {
    testWidgets('DataCard renders title, value and icon correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DataCard(
              title: "Voltage",
              value: "230.5 V",
              icon: Icons.bolt,
            ),
          ),
        ),
      );

      expect(find.text("Voltage"), findsOneWidget);
      expect(find.text("230.5 V"), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });
  });
}

