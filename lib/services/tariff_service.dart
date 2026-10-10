import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Configurable Electricity Tariff & Quota Service
class TariffService {
  static final TariffService _instance = TariffService._internal();
  factory TariffService() => _instance;

  TariffService._internal() {
    _initFirebaseListener();
  }

  DatabaseReference? _settingsRef;
  bool _listenerAttached = false;

  void _initFirebaseListener() {
    if (_listenerAttached) return;
    try {
      if (Firebase.apps.isNotEmpty) {
        _settingsRef = FirebaseDatabase.instance.ref('sensor_logs/esp32_01/settings');
        _listenerAttached = true;
        _settingsRef!.onValue.listen((event) {
          final raw = event.snapshot.value;
          if (raw is Map) {
            final map = Map<dynamic, dynamic>.from(raw);
            if (map.containsKey('tariffRate')) {
              final double? r = double.tryParse(map['tariffRate'].toString());
              if (r != null && r >= 0.0 && r != tariffRateNotifier.value) {
                tariffRateNotifier.value = r;
              }
            }
            if (map.containsKey('quotaUnits')) {
              final double? q = double.tryParse(map['quotaUnits'].toString());
              if (q != null && q > 0.0 && q != quotaUnitsNotifier.value) {
                quotaUnitsNotifier.value = q;
              }
            }
          }
        }, onError: (e) {
          debugPrint("TariffService: listener error: $e");
        });
      }
    } catch (_) {
      // Graceful fallback when Firebase is not initialized (e.g. unit tests)
    }
  }

  void _ensureListener() {
    if (!_listenerAttached) {
      _initFirebaseListener();
    }
  }

  /// Default electricity tariff rate: Rs 7.00 per kWh
  final ValueNotifier<double> tariffRateNotifier = ValueNotifier<double>(7.00);

  /// Default monthly energy quota: 96.0 Units
  final ValueNotifier<double> quotaUnitsNotifier = ValueNotifier<double>(96.0);

  double get tariffRate {
    _ensureListener();
    return tariffRateNotifier.value;
  }

  set tariffRate(double val) {
    if (val >= 0.0) {
      tariffRateNotifier.value = val;
      _saveSettingsToFirebase();
    }
  }

  double get quotaUnits {
    _ensureListener();
    return quotaUnitsNotifier.value;
  }

  set quotaUnits(double val) {
    if (val > 0.0) {
      quotaUnitsNotifier.value = val;
      _saveSettingsToFirebase();
    }
  }

  Future<void> updateTariffRate(double val) async {
    if (val >= 0.0) {
      tariffRateNotifier.value = val;
      await _saveSettingsToFirebase();
    }
  }

  Future<void> updateQuotaUnits(double val) async {
    if (val > 0.0) {
      quotaUnitsNotifier.value = val;
      await _saveSettingsToFirebase();
    }
  }

  Future<void> _saveSettingsToFirebase() async {
    _ensureListener();
    try {
      if (Firebase.apps.isNotEmpty) {
        _settingsRef ??= FirebaseDatabase.instance.ref('sensor_logs/esp32_01/settings');
        await _settingsRef!.update({
          'tariffRate': tariffRateNotifier.value,
          'quotaUnits': quotaUnitsNotifier.value,
          'updatedAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      debugPrint("TariffService: Failed to persist settings to Firebase: $e");
    }
  }

  /// Calculates estimated bill from real kWh consumption
  double calculateBill(double monthlyKWh) {
    if (monthlyKWh <= 0.0) return 0.0;
    return monthlyKWh * tariffRate;
  }
}
