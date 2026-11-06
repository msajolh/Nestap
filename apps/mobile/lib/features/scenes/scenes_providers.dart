import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/rule_repository_impl.dart';
import 'domain/repositories/rule_repository.dart';

final ruleRepositoryProvider = Provider<RuleRepository>(
  (ref) => RuleRepositoryImpl(ref.watch(apiClientProvider)),
);
