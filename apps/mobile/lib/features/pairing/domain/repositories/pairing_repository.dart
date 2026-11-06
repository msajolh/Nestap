/// Adds a new device to a home.
///
/// Phase 1 devices are Tuya-based (Nalite, Uemon), so pairing goes through the
/// Tuya App SDK and the device is then imported into Nestap
/// (`docs/architecture/06-device-compatibility.md` §3.3). Later transports
/// (Nestap firmware, Zigbee/Matter gateway) get their own implementation of
/// this interface; the UI does not change.
abstract interface class PairingRepository {
  /// Sends Wi-Fi credentials to a device in pairing mode and waits until it
  /// is online and added to [homeId]. Returns the new Nestap device id.
  Future<String> pairWifiDevice({
    required String homeId,
    required String ssid,
    required String password,
    String? roomId,
  });

  /// Stops a pairing attempt in progress.
  Future<void> cancel();
}
