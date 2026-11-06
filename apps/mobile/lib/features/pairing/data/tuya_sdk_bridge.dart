import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/error/failures.dart';

/// Session the Nestap backend hands out for the hidden Tuya identity
/// (`POST /v1/connectors/tuya/session`).
class TuyaSession {
  const TuyaSession({
    required this.uid,
    required this.secret,
    required this.tuyaHomeId,
    required this.region,
  });

  factory TuyaSession.fromJson(Map<String, dynamic> json) => TuyaSession(
        uid: json['tuya_uid'] as String,
        secret: json['secret'] as String,
        tuyaHomeId: json['tuya_home_id'] as String,
        region: json['region'] as String,
      );

  final String uid;
  final String secret;
  final String tuyaHomeId;
  final String region;
}

/// The native Tuya App SDK (Android/iOS), reached over a platform channel.
abstract interface class TuyaSdkBridge {
  /// Logs the SDK in with [session], pairs a device over Wi-Fi (EZ, falling
  /// back to AP mode) and returns its Tuya device id.
  Future<String> pairWifi({
    required TuyaSession session,
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 120),
  });

  Future<void> stopPairing();
}

/// Talks to `TuyaPairingPlugin` in `android/` and `ios/`.
///
/// Native side to implement (see apps/mobile/README.md):
///   pairWifi({uid, secret, tuyaHomeId, region, ssid, password, timeoutSec}) → devId
///   stopPairing()
class MethodChannelTuyaSdkBridge implements TuyaSdkBridge {
  const MethodChannelTuyaSdkBridge();

  static const _channel = MethodChannel('net.nestap.app/tuya_pairing');

  @override
  Future<String> pairWifi({
    required TuyaSession session,
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      final devId = await _channel.invokeMethod<String>('pairWifi', {
        'uid': session.uid,
        'secret': session.secret,
        'tuyaHomeId': session.tuyaHomeId,
        'region': session.region,
        'ssid': ssid,
        'password': password,
        'timeoutSec': timeout.inSeconds,
      });
      if (devId == null) throw const PairingFailure('The device did not respond.');
      return devId;
    } on MissingPluginException {
      throw const PairingFailure(
        'Device pairing is not available in this build yet (Tuya SDK plugin missing).',
      );
    } on PlatformException catch (e) {
      throw PairingFailure(switch (e.code) {
        'TIMEOUT' => 'The device was not found. Make sure its light is blinking fast and try again.',
        'WIFI_5GHZ' => 'Connect your phone to a 2.4 GHz Wi-Fi network.',
        _ => e.message ?? 'Pairing failed.',
      });
    }
  }

  @override
  Future<void> stopPairing() async {
    try {
      await _channel.invokeMethod<void>('stopPairing');
    } on MissingPluginException {
      // Nothing to stop.
    }
  }
}

/// Pretends a device paired after a few seconds (demo backend only).
class DemoTuyaSdkBridge implements TuyaSdkBridge {
  Completer<String>? _pending;

  @override
  Future<String> pairWifi({
    required TuyaSession session,
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 120),
  }) {
    final pending = _pending = Completer<String>();
    Timer(const Duration(seconds: 3), () {
      if (!pending.isCompleted) pending.complete('tuya_demo_${DateTime.now().millisecondsSinceEpoch}');
    });
    return pending.future;
  }

  @override
  Future<void> stopPairing() async {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const PairingFailure('Pairing cancelled.'));
    }
  }
}
