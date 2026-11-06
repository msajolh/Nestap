import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../domain/entities/rule.dart';
import '../providers/rules_controller.dart';

class ScenesPage extends ConsumerWidget {
  const ScenesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider);
    final scenes = ref.watch(scenesProvider).value ?? const <Rule>[];
    final automations = ref.watch(automationsProvider).value ?? const <Rule>[];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scenes')),
      body: AsyncValueView(
        value: rules,
        onRetry: () => ref.invalidate(rulesProvider),
        data: (_) => RefreshIndicator(
          onRefresh: () => ref.refresh(rulesProvider.future),
          child: ListView(
            padding: EdgeInsets.all(context.pagePadding),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tap-to-run', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.md),
                    if (scenes.isEmpty)
                      const Text('No scenes yet.')
                    else
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 112,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                        ),
                        children: [for (final scene in scenes) _SceneCard(scene: scene)],
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Automations', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.md),
                    if (automations.isEmpty)
                      const Text('No automations yet.')
                    else
                      Card(
                        child: Column(
                          children: [
                            for (final (i, rule) in automations.indexed) ...[
                              if (i > 0) const Divider(),
                              _AutomationTile(rule: rule),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneCard extends ConsumerStatefulWidget {
  const _SceneCard({required this.scene});

  final Rule scene;

  @override
  ConsumerState<_SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends ConsumerState<_SceneCard> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      await ref.read(rulesProvider.notifier).run(widget.scene);
      if (mounted) context.showMessage('"${widget.scene.name}" is running');
    } on Object catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(widget.scene.colorHex) ?? AppColors.cyan400;
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : AppColors.navy;

    return Card(
      color: color,
      child: InkWell(
        onTap: _running ? null : _run,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _running
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
                    )
                  : Icon(_iconFor(widget.scene.icon), color: foreground),
              const Spacer(),
              Text(
                widget.scene.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutomationTile extends ConsumerWidget {
  const _AutomationTile({required this.rule});

  final Rule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
        secondary: const Icon(Icons.auto_mode_rounded),
        title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: rule.summary == null ? null : Text(rule.summary!),
        value: rule.enabled,
        onChanged: (enabled) async {
          try {
            await ref.read(rulesProvider.notifier).setEnabled(rule, enabled);
          } on Object catch (e) {
            if (context.mounted) context.showError(e);
          }
        },
      );
}

IconData _iconFor(String? name) => switch (name) {
      'sunny' => Icons.wb_sunny_rounded,
      'logout' => Icons.logout_rounded,
      'movie' => Icons.movie_rounded,
      'bed' => Icons.bed_rounded,
      'home' => Icons.home_rounded,
      _ => Icons.auto_awesome_rounded,
    };

Color? _parseHex(String? hex) {
  if (hex == null) return null;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}
