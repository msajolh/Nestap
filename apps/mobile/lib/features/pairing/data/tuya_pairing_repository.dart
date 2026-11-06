import '../../../core/network/api_client.dart';
import '../domain/repositories/pairing_repository.dart';
import 'tuya_sdk_bridge.dart';

/// Phase 1 pairing: Tuya SDK on the phone, then import into Nestap.
class TuyaPairingRepository implements PairingRepository {
  const TuyaPairingRepository(this._api, this._sdk);

  final ApiClient _api;
  final TuyaSdkBridge _sdk;

  @override
  Future<String> pairWifiDevice({
    required String homeId,
    required String ssid,
    required String password,
    String? roomId,
  }) async {
    // 1. Hidden Tuya user + Tuya home for this Nestap home.
    final session = TuyaSession.fromJson(
      await _api.post('/v1/connectors/tuya/session', body: {'home_id': homeId}),
    );

    // 2. Native SDK pairs the device onto Tuya's cloud.
    final tuyaDeviceId = await _sdk.pairWifi(
      session: session,
      ssid: ssid,
      password: password,
    );

    // 3. Nestap imports it (profile match, device row, shadow).
    final device = await _api.post(
      '/v1/devices/import',
      body: {
        'provider': 'tuya',
        'external_id': tuyaDeviceId,
        'home_id': homeId,
        'room_id': roomId,
      },
      idempotent: true,
    );
    return device['id'] as String;
  }

  @override
  Future<void> cancel() => _sdk.stopPairing();
}
