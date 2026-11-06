import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/day_selector.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../devices/domain/entities/device.dart';
import '../../../devices/presentation/providers/home_devices_controller.dart';
import '../../../devices/presentation/widgets/device_visuals.dart';
import '../../domain/entities/rule.dart';
import '../../domain/entities/rule_draft.dart';
import '../providers/rules_controller.dart';
import '../widgets/rule_visuals.dart';

/// "If / Then" builder for scenes (Then only) and automations (If + Then).
class RuleEditorPage extends ConsumerStatefulWidget {
  const RuleEditorPage({required this.kind, super.key});

  final RuleKind kind;

  @override
  ConsumerState<RuleEditorPage> createState() => _RuleEditorPageState();
}

class _RuleEditorPageState extends ConsumerState<RuleEditorPage> {
  late RuleDraft _draft = RuleDraft(kind: widget.kind);
  final _name = TextEditingController();
  List<String> _problems = const [];
  bool _saving = false;

  bool get _automation => widget.kind == RuleKind.automation;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(RuleDraft draft) => setState(() {
        _draft = draft;
        if (_problems.isNotEmpty) _problems = draft.copyWith(name: _name.text).validate();
      });

  Future<void> _save() async {
    final draft = _draft.copyWith(name: _name.text);
    final problems = draft.validate();
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(rulesProvider.notifier).create(draft);
      if (!mounted) return;
      context.showMessage('"${draft.name.trim()}" saved');
      context.pop();
    } on Object catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCondition(List<Device> devices) async {
    final condition = await showAppSheet<RuleCondition>(
      context,
      title: 'Add condition',
      builder: (_) => _ConditionPicker(devices: devices),
    );
    if (condition != null) _update(_draft.copyWith(conditions: [..._draft.conditions, condition]));
  }

  Future<void> _addAction(List<Device> devices) async {
    final action = await showAppSheet<RuleAction>(
      context,
      title: 'Add action',
      builder: (_) => _ActionPicker(devices: devices),
    );
    if (action != null) _update(_draft.copyWith(actions: [..._draft.actions, action]));
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(homeDevicesProvider).value ?? const <Device>[];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_automation ? 'New automation' : 'New scene'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _saving
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : TextButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_automation) ...[
                  _ScenePreview(name: _name.text, icon: _draft.icon, colorHex: _draft.colorHex),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: _automation ? 'Lights on at sunset' : 'Movie time',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (!_automation) ...[
                  const SectionLabel('Look'),
                  _AppearancePicker(
                    icon: _draft.icon,
                    colorHex: _draft.colorHex,
                    onIcon: (icon) => _update(_draft.copyWith(icon: icon)),
                    onColor: (color) => _update(_draft.copyWith(colorHex: color)),
                  ),
                ],
                if (_automation) ...[
                  SectionLabel(
                    'If',
                    trailing: SegmentedButton<ConditionMatch>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: ConditionMatch.any, label: Text('Any')),
                        ButtonSegment(value: ConditionMatch.all, label: Text('All')),
                      ],
                      selected: {_draft.match},
                      onSelectionChanged: (s) => _update(_draft.copyWith(match: s.first)),
                    ),
                  ),
                  _StepCard(
                    addLabel: 'Add condition',
                    onAdd: () => _addCondition(devices),
                    children: [
                      for (final (i, c) in _draft.conditions.indexed)
                        _StepTile(
                          icon: c is ScheduleCondition ? Icons.alarm_rounded : Icons.sensors_rounded,
                          title: switch (c) {
                            ScheduleCondition(:final hour, :final minute) =>
                              '${Formatters.two(hour)}:${Formatters.two(minute)}',
                            DeviceStateCondition(:final label) => label,
                          },
                          subtitle: switch (c) {
                            ScheduleCondition(:final days) => Formatters.days(days),
                            DeviceStateCondition() => 'When it changes to this',
                          },
                          onRemove: () => _update(
                            _draft.copyWith(conditions: [..._draft.conditions]..removeAt(i)),
                          ),
                        ),
                    ],
                  ),
                ],
                const SectionLabel('Then'),
                _StepCard(
                  addLabel: 'Add action',
                  onAdd: () => _addAction(devices),
                  children: [
                    for (final (i, a) in _draft.actions.indexed)
                      _StepTile(
                        icon: a is DelayAction ? Icons.hourglass_bottom_rounded : Icons.bolt_rounded,
                        title: switch (a) {
                          DeviceAction(:final label) => label,
                          DelayAction(:final seconds) => 'Wait ${_duration(seconds)}',
                        },
                        onRemove: () => _update(
                          _draft.copyWith(actions: [..._draft.actions]..removeAt(i)),
                        ),
                      ),
                  ],
                ),
                if (_problems.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  for (final p in _problems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(p, style: TextStyle(color: scheme.error))),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _duration(int seconds) =>
    seconds >= 3600 ? '${seconds ~/ 3600} h' : (seconds >= 60 ? '${seconds ~/ 60} min' : '$seconds s');

String _dpLabel(String code) => switch (code) {
      'switch_led' => 'Light',
      _ when code.startsWith('switch_') => gangLabel(code),
      _ => code,
    };

/// What a device can be told to do in a scene.
List<(String, Map<String, Object?>)> _actionOptions(Device device) {
  if (device.category == DeviceCategory.curtain) {
    return [
      ('Open', {'control': 'open'}),
      ('Close', {'control': 'close'}),
    ];
  }
  final gangs = device.switchCodes;
  return [
    if (device.powerCode != null) ...[
      ('Turn on', device.allChannels(true)),
      ('Turn off', device.allChannels(false)),
    ],
    if (gangs.length > 1)
      for (final gang in gangs) ...[
        ('${gangLabel(gang)} on', {gang: true}),
        ('${gangLabel(gang)} off', {gang: false}),
      ],
  ];
}

/// Live preview of the scene card as it will look on the Scenes tab.
class _ScenePreview extends StatelessWidget {
  const _ScenePreview({required this.name, required this.icon, required this.colorHex});

  final String name;
  final String icon;
  final String colorHex;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(colorHex) ?? AppColors.cyan400;
    final fg = foregroundOn(color);
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 200,
        height: 112,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(AppRadius.lg),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconForRule(icon), color: fg),
            const Spacer(),
            Text(
              name.trim().isEmpty ? 'Scene name' : name.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker({
    required this.icon,
    required this.colorHex,
    required this.onIcon,
    required this.onColor,
  });

  final String icon;
  final String colorHex;
  final ValueChanged<String> onIcon;
  final ValueChanged<String> onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final hex in ruleColors)
                  InkResponse(
                    onTap: () => onColor(hex),
                    radius: 22,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: parseHexColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hex == colorHex ? scheme.onSurface : scheme.outline,
                          width: hex == colorHex ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final MapEntry(key: name, value: glyph) in ruleIcons.entries)
                  IconButton.filledTonal(
                    isSelected: name == icon,
                    onPressed: () => onIcon(name),
                    style: IconButton.styleFrom(
                      backgroundColor: name == icon ? AppColors.cyan400 : null,
                      foregroundColor: name == icon ? AppColors.navy : null,
                    ),
                    icon: Icon(glyph),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.children, required this.addLabel, required this.onAdd});

  final List<Widget> children;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            for (final child in children) ...[child, const Divider(indent: 56)],
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.brand),
              title: Text(addLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: onAdd,
            ),
          ],
        ),
      );
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.icon, required this.title, required this.onRemove, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.cyan400.withValues(alpha: 0.2),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(icon, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close_rounded),
          onPressed: onRemove,
        ),
      );
}

/// Sheet: choose "Schedule" or "Device changes", then fill it in.
class _ConditionPicker extends StatefulWidget {
  const _ConditionPicker({required this.devices});

  final List<Device> devices;

  @override
  State<_ConditionPicker> createState() => _ConditionPickerState();
}

enum _ConditionMode { choose, schedule, device }

class _ConditionPickerState extends State<_ConditionPicker> {
  _ConditionMode _mode = _ConditionMode.choose;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 30);
  Set<int> _days = {1, 2, 3, 4, 5, 6, 7};

  @override
  Widget build(BuildContext context) => switch (_mode) {
        _ConditionMode.choose => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChoiceTile(
                icon: Icons.alarm_rounded,
                title: 'Schedule',
                subtitle: 'At a time on chosen days',
                onTap: () => setState(() => _mode = _ConditionMode.schedule),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChoiceTile(
                icon: Icons.sensors_rounded,
                title: 'When a device changes',
                subtitle: 'A switch turns on or off',
                onTap: () => setState(() => _mode = _ConditionMode.device),
              ),
            ],
          ),
        _ConditionMode.schedule => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded),
                label: Text('${Formatters.two(_time.hour)}:${Formatters.two(_time.minute)}'),
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DaySelector(selected: _days, onChanged: (d) => setState(() => _days = d)),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  ScheduleCondition(hour: _time.hour, minute: _time.minute, days: _days.toList()..sort()),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        _ConditionMode.device => _DeviceOptionList(
            devices: widget.devices,
            optionsFor: (device) => [
              for (final MapEntry(key: code, value: value) in device.state.entries)
                if (value is bool)
                  for (final on in [true, false])
                    (
                      '${_dpLabel(code)} ${on ? 'on' : 'off'}',
                      () => Navigator.pop(
                            context,
                            DeviceStateCondition(
                              deviceId: device.id,
                              dp: code,
                              value: on,
                              label: '${device.name} · ${_dpLabel(code)} ${on ? 'on' : 'off'}',
                            ),
                          ),
                    ),
            ],
          ),
      };
}

/// Sheet: "Control a device" or "Delay".
class _ActionPicker extends StatefulWidget {
  const _ActionPicker({required this.devices});

  final List<Device> devices;

  @override
  State<_ActionPicker> createState() => _ActionPickerState();
}

class _ActionPickerState extends State<_ActionPicker> {
  bool? _device;

  @override
  Widget build(BuildContext context) => switch (_device) {
        null => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChoiceTile(
                icon: Icons.bolt_rounded,
                title: 'Control a device',
                subtitle: 'Turn on, turn off, open, close',
                onTap: () => setState(() => _device = true),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChoiceTile(
                icon: Icons.hourglass_bottom_rounded,
                title: 'Delay',
                subtitle: 'Wait before the next action',
                onTap: () => setState(() => _device = false),
              ),
            ],
          ),
        true => _DeviceOptionList(
            devices: widget.devices,
            optionsFor: (device) => [
              for (final (label, dps) in _actionOptions(device))
                (
                  label,
                  () => Navigator.pop(
                        context,
                        DeviceAction(deviceId: device.id, dps: dps, label: '${device.name} · $label'),
                      ),
                ),
            ],
          ),
        false => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final minutes in [1, 5, 10, 15, 30, 60])
                ActionChip(
                  label: Text(minutes == 60 ? '1 hour' : '$minutes min'),
                  onPressed: () => Navigator.pop(context, DelayAction(minutes * 60)),
                ),
            ],
          ),
      };
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          leading: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.activeGradient),
            child: Icon(icon, color: AppColors.navy),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

/// Devices as expandable rows, each listing what can be picked for it.
class _DeviceOptionList extends StatelessWidget {
  const _DeviceOptionList({required this.devices, required this.optionsFor});

  final List<Device> devices;
  final List<(String, VoidCallback)> Function(Device device) optionsFor;

  @override
  Widget build(BuildContext context) {
    final usable = [
      for (final d in devices)
        if (optionsFor(d).isNotEmpty) d,
    ];
    if (usable.isEmpty) {
      return const MessageView(icon: Icons.devices_other_rounded, title: 'No devices to choose');
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final device in usable)
          ExpansionTile(
            leading: Icon(device.icon),
            title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            children: [
              for (final (label, onTap) in optionsFor(device))
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: AppSpacing.lg),
                  title: Text(label),
                  onTap: onTap,
                ),
            ],
          ),
      ],
    );
  }
}
