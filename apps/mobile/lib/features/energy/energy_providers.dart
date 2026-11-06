import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/energy_repository_impl.dart';
import 'domain/entities/energy_report.dart';
import 'domain/repositories/energy_repository.dart';

final energyRepositoryProvider = Provider<EnergyRepository>(
  (ref) => EnergyRepositoryImpl(ref.watch(apiClientProvider)),
);

typedef EnergyQuery = ({String deviceId, EnergyRange range});

/// Records compare by value, so each (device, range) pair is cached once.
final deviceEnergyProvider = FutureProvider.family<EnergyReport, EnergyQuery>(
  (ref, q) => ref.watch(energyRepositoryProvider).getDeviceEnergy(q.deviceId, q.range),
);
