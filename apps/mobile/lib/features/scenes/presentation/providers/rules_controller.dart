import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../home/home_providers.dart';
import '../../domain/entities/rule.dart';
import '../../domain/entities/rule_draft.dart';
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

  /// Validates, saves, and adds the new rule to the list.
  Future<void> create(RuleDraft draft) async {
    final problems = draft.validate();
    if (problems.isNotEmpty) throw ValidationFailure(problems.first);
    final repository = ref.read(ruleRepositoryProvider);
    final home = await ref.read(currentHomeProvider.future);
    if (home == null) throw const ValidationFailure('Create a home first.');
    final rule = await repository.create(home.id, draft);
    final rules = state.value;
    if (rules != null && ref.mounted) state = AsyncData([...rules, rule]);
  }

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
