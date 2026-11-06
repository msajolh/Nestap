import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/home_repository_impl.dart';
import 'domain/entities/home.dart';
import 'domain/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepositoryImpl(ref.watch(apiClientProvider)),
);

final homesProvider = FutureProvider<List<Home>>(
  (ref) => ref.watch(homeRepositoryProvider).getHomes(),
);

/// The home the user last picked, remembered across launches.
final selectedHomeIdProvider = NotifierProvider<SelectedHomeId, String?>(
  SelectedHomeId.new,
);

class SelectedHomeId extends Notifier<String?> {
  static const _key = 'home.selected_id';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  void select(String homeId) {
    state = homeId;
    ref.read(sharedPreferencesProvider).setString(_key, homeId);
  }
}

/// The home on screen: the remembered one if it still exists, else the first.
// Watch everything before the first `await`: Riverpod 3 rejects a ref used
// after its provider has rebuilt.
final currentHomeProvider = FutureProvider<Home?>((ref) async {
  final selected = ref.watch(selectedHomeIdProvider);
  final homes = await ref.watch(homesProvider.future);
  if (homes.isEmpty) return null;
  return homes.firstWhere((h) => h.id == selected, orElse: () => homes.first);
});

final roomsProvider = FutureProvider<List<Room>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final home = await ref.watch(currentHomeProvider.future);
  if (home == null) return const [];
  return repository.getRooms(home.id);
});

/// Room filter on the dashboard; null means "All". Resets when the home changes.
final selectedRoomIdProvider = NotifierProvider<SelectedRoomId, String?>(
  SelectedRoomId.new,
);

class SelectedRoomId extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(currentHomeProvider.select((home) => home.value?.id));
    return null;
  }

  void select(String? roomId) => state = roomId;
}
