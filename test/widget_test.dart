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

    test('TEST 6: Authoritative ESP32 totalEnergy delta calculation (0.10 kWh => Rs 0.70)', () {
      final t1 = DateTime(2026, 9, 12, 10, 0, 0);
      final t2 = DateTime(2026, 9, 12, 10, 10, 0);

      final r1 = EnergyReading(
        key: 'r1', timestamp: t1, voltage1: 230, voltage2: 230,
        current1: 2.6, current2: 0, power1: 600.0, power2: 0.0,
        energy1: 0.0, energy2: 0.0, totalCurrent: 2.6, totalPower: 600.0, totalEnergy: 0.0,
      );
      final r2 = EnergyReading(
        key: 'r2', timestamp: t2, voltage1: 230, voltage2: 230,
        current1: 2.6, current2: 0, power1: 600.0, power2: 0.0,
        energy1: 0.10, energy2: 0.0, totalCurrent: 2.6, totalPower: 600.0, totalEnergy: 0.10,
      );

      final metrics = EnergyCalculator.calculateMetrics(
        latest: r2,
        history: [r1, r2],
        tariffRate: 7.00,
      );

      expect(metrics.todayEnergyKWh, closeTo(0.10, 0.0001));
      expect(metrics.thisMonthEnergyKWh, closeTo(0.10, 0.0001));
      expect(metrics.estimatedBill, closeTo(0.70, 0.0001)); // 0.10 kWh * Rs 7.00 = Rs 0.70
    });

    test('TEST 7: Reset / ESP32 Reboot Resilience in totalEnergy delta accumulation', () {
      final t1 = DateTime(2026, 9, 12, 10, 0, 0);
      final t2 = DateTime(2026, 9, 12, 10, 10, 0);
      final t3 = DateTime(2026, 9, 12, 10, 20, 0); // ESP32 reboots, counter resets to 0.5 kWh
      final t4 = DateTime(2026, 9, 12, 10, 30, 0);

      final history = [
        EnergyReading(key: 'r1', timestamp: t1, voltage1: 230, voltage2: 230, current1: 1, current2: 0, power1: 230, power2: 0, energy1: 5, energy2: 5, totalCurrent: 1, totalPower: 230, totalEnergy: 10.0),
        EnergyReading(key: 'r2', timestamp: t2, voltage1: 230, voltage2: 230, current1: 1, current2: 0, power1: 230, power2: 0, energy1: 6, energy2: 6, totalCurrent: 1, totalPower: 230, totalEnergy: 12.0), // Delta = 2.0
        EnergyReading(key: 'r3', timestamp: t3, voltage1: 230, voltage2: 230, current1: 1, current2: 0, power1: 230, power2: 0, energy1: 0.25, energy2: 0.25, totalCurrent: 1, totalPower: 230, totalEnergy: 0.5), // Reboot -> Delta = 0.5
        EnergyReading(key: 'r4', timestamp: t4, voltage1: 230, voltage2: 230, current1: 1, current2: 0, power1: 230, power2: 0, energy1: 1.0, energy2: 1.0, totalCurrent: 1, totalPower: 230, totalEnergy: 2.0), // Delta = 1.5
      ];

      final metrics = EnergyCalculator.calculateMetrics(
        latest: history.last,
        history: history,
        tariffRate: 7.00,
      );

      // Total expected energy = 2.0 + 0.5 + 1.5 = 4.0 kWh
      expect(metrics.todayEnergyKWh, closeTo(4.0, 0.0001));
      expect(metrics.estimatedBill, closeTo(28.00, 0.0001)); // 4.0 kWh * Rs 7.00 = Rs 28.00
    });

    test('TEST 8: Tariff Billing calculation from real kWh', () {
      final tariffService = TariffService();
      tariffService.tariffRate = 7.50; // Rs 7.50 per kWh

      expect(tariffService.calculateBill(0.0), 0.0);
      expect(tariffService.calculateBill(10.0), 75.0);
      expect(tariffService.calculateBill(12.64), closeTo(94.80, 0.01));
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

