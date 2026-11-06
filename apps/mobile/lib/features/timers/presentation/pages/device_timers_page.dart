import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/day_selector.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../devices/domain/entities/device.dart';
import '../../../devices/presentation/providers/home_devices_controller.dart';
import '../../domain/entities/device_timer.dart';
import '../../timers_providers.dart';

class DeviceTimersPage extends ConsumerStatefulWidget {
  const DeviceTimersPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  ConsumerState<DeviceTimersPage> createState() => _DeviceTimersPageState();
}

class _DeviceTimersPageState extends ConsumerState<DeviceTimersPage> {
  /// Swiped-away timers, hidden at once so Dismissible never sees them again
  /// while the list reloads.
  final _removed = <String>{};

  String get deviceId => widget.deviceId;

  Future<void> _guard(Future<void> Function() action) async {
    // Captured up front: `ref` is unusable if the page closes mid-request,
    // but the cached list must still be refreshed.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) context.showError(e);
    }
    container.invalidate(deviceTimersProvider(deviceId));
  }

  Future<void> _add(Device device) async {
    final draft = await showAppSheet<TimerDraft>(
      context,
      title: 'New schedule',
      builder: (_) => _TimerEditor(device: device),
    );
    if (draft == null || !mounted) return;
    await _guard(() => ref.read(timerRepositoryProvider).create(deviceId, draft));
  }

  @override
  Widget build(BuildContext context) {
    final timers = ref
        .watch(deviceTimersProvider(deviceId))
        .whenData((list) => list.where((t) => !_removed.contains(t.id)).toList());
    final device = ref.watch(deviceByIdProvider(deviceId)).value;
    final repository = ref.read(timerRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(device == null ? 'Schedules' : 'Schedules · ${device.name}')),
      floatingActionButton: device == null || device.powerCode == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(device),
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('Add schedule'),
            ),
      body: AsyncValueView(
        value: timers,
        onRetry: () => ref.invalidate(deviceTimersProvider(deviceId)),
        data: (timers) {
          if (timers.isEmpty) {
            return const MessageView(
              icon: Icons.schedule_rounded,
              title: 'No schedules yet',
              message: 'Turn this device on or off automatically at set times.',
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(context.pagePadding, context.pagePadding, context.pagePadding, 96),
            itemCount: timers.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final timer = timers[i];
              return ResponsiveCenter(
                maxWidth: 720,
                child: Dismissible(
                  key: ValueKey(timer.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.xl),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.all(AppRadius.lg),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() => _removed.add(timer.id));
                    _guard(() => repository.delete(timer.id));
                  },
                  child: _TimerCard(
                    timer: timer,
                    onToggle: (enabled) =>
                        _guard(() => repository.setEnabled(timer.id, enabled: enabled)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.timer, required this.onToggle});

  final DeviceTimer timer;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = switch (timer.turnsOn) {
      true => 'Turn on',
      false => 'Turn off',
      null => 'Set ${timer.dps.length} values',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: timer.enabled ? 1 : 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Formatters.two(timer.hour)}:${Formatters.two(timer.minute)}',
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${Formatters.days(timer.days)} · $action',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Switch(
              value: timer.enabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onToggle(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet form: time, repeat days, on/off.
class _TimerEditor extends StatefulWidget {
  const _TimerEditor({required this.device});

  final Device device;

  @override
  State<_TimerEditor> createState() => _TimerEditorState();
}

class _TimerEditorState extends State<_TimerEditor> {
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  Set<int> _days = {1, 2, 3, 4, 5};
  bool _turnOn = true;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _pickTime,
          borderRadius: const BorderRadius.all(AppRadius.lg),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.all(AppRadius.lg),
            ),
            child: Text(
              '${Formatters.two(_time.hour)}:${Formatters.two(_time.minute)}',
              textAlign: TextAlign.center,
              style: text.displayMedium?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Repeat · ${Formatters.days(_days.toList())}', style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        DaySelector(
          selected: _days,
          onChanged: (days) => setState(() => _days = days),
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, icon: Icon(Icons.power_rounded), label: Text('Turn on')),
            ButtonSegment(value: false, icon: Icon(Icons.power_off_rounded), label: Text('Turn off')),
          ],
          selected: {_turnOn},
          onSelectionChanged: (s) => setState(() => _turnOn = s.first),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            TimerDraft(
              hour: _time.hour,
              minute: _time.minute,
              days: _days.toList()..sort(),
              dps: widget.device.allChannels(_turnOn),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

