import 'package:flutter/foundation.dart';

/// Configurable Electricity Tariff & Quota Service
class TariffService {
  static final TariffService _instance = TariffService._internal();
  factory TariffService() => _instance;
  TariffService._internal();

  /// Default electricity tariff rate: Rs 7.00 per kWh
  final ValueNotifier<double> tariffRateNotifier = ValueNotifier<double>(7.00);

  /// Default monthly energy quota: 96.0 Units
  final ValueNotifier<double> quotaUnitsNotifier = ValueNotifier<double>(96.0);

  double get tariffRate => tariffRateNotifier.value;
  set tariffRate(double val) {
    if (val >= 0.0) {
      tariffRateNotifier.value = val;
    }
  }

  double get quotaUnits => quotaUnitsNotifier.value;
  set quotaUnits(double val) {
    if (val > 0.0) {
      quotaUnitsNotifier.value = val;
    }
  }

  /// Calculates estimated bill from real kWh consumption
  double calculateBill(double monthlyKWh) {
    if (monthlyKWh <= 0.0) return 0.0;
    return monthlyKWh * tariffRate;
  }
}
