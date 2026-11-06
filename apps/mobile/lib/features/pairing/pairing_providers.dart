import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/tuya_pairing_repository.dart';
import 'data/tuya_sdk_bridge.dart';
import 'domain/repositories/pairing_repository.dart';

final tuyaSdkBridgeProvider = Provider<TuyaSdkBridge>(
  (ref) => ref.watch(appConfigProvider).useDemoBackend
      ? DemoTuyaSdkBridge()
      : const MethodChannelTuyaSdkBridge(),
);

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => TuyaPairingRepository(
    ref.watch(apiClientProvider),
    ref.watch(tuyaSdkBridgeProvider),
  ),
);
