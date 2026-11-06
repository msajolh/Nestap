import '../../../core/network/api_client.dart';
import '../domain/entities/energy_report.dart';
import '../domain/repositories/energy_repository.dart';

/// `GET /v1/devices/{id}/energy?range=day|week|month` (history service,
/// backed by the `telemetry.energy_hourly` continuous aggregate).
class EnergyRepositoryImpl implements EnergyRepository {
  const EnergyRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<EnergyReport> getDeviceEnergy(String deviceId, EnergyRange range) async {
    // The server buckets by the home's timezone, so no tz is sent.
    final json = await _api.get('/v1/devices/$deviceId/energy', query: {'range': range.name});
    final points = [
      for (final p in (json['points'] as List<Object?>? ?? const []).cast<JsonMap>())
        EnergyPoint(
          start: DateTime.parse(p['start'] as String).toLocal(),
          kwh: (p['kwh'] as num).toDouble(),
        ),
    ];
    return EnergyReport(
      range: range,
      totalKwh: (json['total_kwh'] as num?)?.toDouble() ??
          points.fold<double>(0, (sum, p) => sum + p.kwh),
      points: points,
    );
  }
}
