import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartenergy/models/energy_models.dart';
import 'package:smartenergy/services/energy_service.dart';
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
      expect(forecast.monthToDateUnits, 20.0); // 25.0 - 5.0
      expect(forecast.remainingUnits, 76.0);   // 96.0 - 20.0
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
