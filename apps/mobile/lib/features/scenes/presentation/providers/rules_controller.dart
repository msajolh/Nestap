import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/home_providers.dart';
import '../../domain/entities/rule.dart';
import '../../scenes_providers.dart';

final rulesProvider = AsyncNotifierProvider<RulesController, List<Rule>>(
  RulesController.new,
);

class RulesController extends AsyncNotifier<List<Rule>> {
  @override
  Future<List<Rule>> build() async {
    final repository = ref.watch(ruleRepositoryProvider);
    final home = await ref.watch(currentHomeProvider.future);
    if (home == null) return const [];
    return repository.getRules(home.id);
  }

  Future<void> run(Rule scene) => ref.read(ruleRepositoryProvider).runScene(scene.id);

  /// Optimistic toggle; reverts if the server refuses.
  Future<void> setEnabled(Rule rule, bool enabled) async {
    _replace(rule.copyWith(enabled: enabled));
    try {
      await ref.read(ruleRepositoryProvider).setEnabled(rule.id, enabled: enabled);
    } on Object {
      if (ref.mounted) _replace(rule);
      rethrow;
    }
  }

  void _replace(Rule updated) {
    final rules = state.value;
    if (rules == null) return;
    state = AsyncData([for (final r in rules) r.id == updated.id ? updated : r]);
  }
}

final scenesProvider = Provider<AsyncValue<List<Rule>>>(
  (ref) => ref
      .watch(rulesProvider)
      .whenData((rules) => rules.where((r) => r.kind == RuleKind.scene).toList()),
);

final automationsProvider = Provider<AsyncValue<List<Rule>>>(
  (ref) => ref
      .watch(rulesProvider)
      .whenData((rules) => rules.where((r) => r.kind == RuleKind.automation).toList()),
);
