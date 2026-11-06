import '../entities/energy_report.dart';

abstract interface class EnergyRepository {
  /// Energy for today (hourly), the last 7 days or the last 30 days (daily),
  /// in the home's timezone.
  Future<EnergyReport> getDeviceEnergy(String deviceId, EnergyRange range);
}
