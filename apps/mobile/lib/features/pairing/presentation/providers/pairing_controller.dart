import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../pairing_providers.dart';

sealed class PairingState {
  const PairingState();
}

final class PairingIdle extends PairingState {
  const PairingIdle();
}

final class PairingInProgress extends PairingState {
  const PairingInProgress();
}

final class PairingSucceeded extends PairingState {
  const PairingSucceeded(this.deviceId);

  final String deviceId;
}

final class PairingFailed extends PairingState {
  const PairingFailed(this.message);

  final String message;
}

/// The Add device page calls [PairingController.reset] when it opens.
final pairingControllerProvider = NotifierProvider<PairingController, PairingState>(
  PairingController.new,
);

class PairingController extends Notifier<PairingState> {
  @override
  PairingState build() => const PairingIdle();

  Future<void> start({
    required String homeId,
    required String ssid,
    required String password,
    String? roomId,
  }) async {
    if (ssid.trim().isEmpty) {
      state = const PairingFailed('Enter your Wi-Fi network name.');
      return;
    }
    state = const PairingInProgress();
    try {
      final deviceId = await ref.read(pairingRepositoryProvider).pairWifiDevice(
            homeId: homeId,
            roomId: roomId,
            ssid: ssid.trim(),
            password: password,
          );
      if (ref.mounted) state = PairingSucceeded(deviceId);
    } on Failure catch (e) {
      if (ref.mounted) state = PairingFailed(e.message);
    } on Object {
      if (ref.mounted) state = const PairingFailed('Pairing failed. Please try again.');
    }
  }

  Future<void> cancel() async {
    await ref.read(pairingRepositoryProvider).cancel();
    if (ref.mounted) state = const PairingIdle();
  }

  void reset() => state = const PairingIdle();
}
