import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Whether the welcome slides were shown on this install.
final onboardingSeenProvider = NotifierProvider<OnboardingSeen, bool>(
  OnboardingSeen.new,
);

class OnboardingSeen extends Notifier<bool> {
  static const _key = 'onboarding.seen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void markSeen() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}
