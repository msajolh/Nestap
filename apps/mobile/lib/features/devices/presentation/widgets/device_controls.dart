import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/device.dart';
import 'device_visuals.dart';

typedef SendDps = Future<void> Function(Map<String, Object?> dps);

/// Picks the control panel for a device's category.
class DeviceControls extends StatelessWidget {
  const DeviceControls({required this.device, required this.send, super.key});

  final Device device;
  final SendDps send;

  @override
  Widget build(BuildContext context) => switch (device.category) {
        DeviceCategory.curtain => CurtainControls(device: device, send: send),
        DeviceCategory.light => LightControls(device: device, send: send),
        DeviceCategory.switchPanel ||
        DeviceCategory.socket =>
          SwitchControls(device: device, send: send),
        DeviceCategory.sensor ||
        DeviceCategory.gateway ||
        DeviceCategory.unknown =>
          GenericControls(device: device, send: send),
      };
}

/// Wall switches (1–4 gangs) and sockets, plus metering when available.
class SwitchControls extends StatelessWidget {
  const SwitchControls({required this.device, required this.send, super.key});

  final Device device;
  final SendDps send;

  @override
  Widget build(BuildContext context) {
    final gangs = device.switchCodes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = gangs.length == 1
                ? 1
                : (constraints.maxWidth > 520 ? min(gangs.length, 4) : 2);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: gangs.length == 1 ? 1.6 : 1.1,
              children: [
                for (final code in gangs)
                  _GangButton(
                    label: gangs.length == 1 ? 'Power' : gangLabel(code),
                    on: device.state[code] == true,
                    onTap: () => send({code: device.state[code] != true}),
                  ),
              ],
            );
          },
        ),
        if (gangs.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => send(device.allChannels(false)),
                  child: const Text('All off'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => send(device.allChannels(true)),
                  child: const Text('All on'),
                ),
              ),
            ],
          ),
        ],
        if (device.hasMetering) ...[
          const SizedBox(height: AppSpacing.xl),
          _MeteringRow(device: device),
        ],
      ],
    );
  }
}

class _GangButton extends StatelessWidget {
  const _GangButton({
    required this.label,
    required this.on,
    required this.onTap,
    this.icon = Icons.power_settings_new_rounded,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      toggled: on,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: const BorderRadius.all(AppRadius.xl),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(AppRadius.xl),
              gradient: on ? AppColors.activeGradient : null,
              color: on ? null : scheme.surfaceContainer,
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: AppColors.cyan400.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: on ? AppColors.navy : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: on ? AppColors.navy : scheme.onSurface,
                  ),
                ),
                Text(
                  on ? 'On' : 'Off',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: on ? AppColors.navy : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeteringRow extends StatelessWidget {
  const _MeteringRow({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _Metric(label: 'Power', value: device.powerW, unit: 'W')),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _Metric(label: 'Voltage', value: device.voltageV, unit: 'V')),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Metric(
              label: 'Current',
              value: device.currentMa == null ? null : device.currentMa! / 1000,
              unit: 'A',
              decimals: 2,
            ),
          ),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    this.decimals = 1,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(
              TextSpan(
                text: value?.toStringAsFixed(decimals) ?? '–',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                children: [
                  TextSpan(text: ' $unit', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lights: power plus brightness.
class LightControls extends StatelessWidget {
  const LightControls({required this.device, required this.send, super.key});

  final Device device;
  final SendDps send;

  @override
  Widget build(BuildContext context) {
    final on = device.state['switch_led'] == true;
    final brightness = device.brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 180,
          child: _GangButton(
            label: 'Light',
            icon: Icons.lightbulb_rounded,
            on: on,
            onTap: () => send({'switch_led': !on}),
          ),
        ),
        if (brightness != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Brightness', style: Theme.of(context).textTheme.titleMedium),
          _CommitSlider(
            value: brightness,
            enabled: on,
            label: (v) => '${(v * 100).round()}%',
            onCommit: (v) => send({'bright_value': (10 + v * 990).round()}),
          ),
        ],
      ],
    );
  }
}

/// Curtains: open / stop / close and an exact position.
class CurtainControls extends StatelessWidget {
  const CurtainControls({required this.device, required this.send, super.key});

  final Device device;
  final SendDps send;

  @override
  Widget build(BuildContext context) {
    final position = device.position;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (action, icon, label) in [
              ('open', Icons.unfold_more_rounded, 'Open'),
              ('stop', Icons.pause_rounded, 'Stop'),
              ('close', Icons.unfold_less_rounded, 'Close'),
            ]) ...[
              Expanded(
                child: SizedBox(
                  height: 120,
                  child: _GangButton(
                    label: label,
                    icon: icon,
                    on: device.state['control'] == action,
                    onTap: () => send({'control': action}),
                  ),
                ),
              ),
              if (action != 'close') const SizedBox(width: AppSpacing.md),
            ],
          ],
        ),
        if (position != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Position', style: Theme.of(context).textTheme.titleMedium),
          _CommitSlider(
            value: position / 100,
            label: (v) => '${(v * 100).round()}% open',
            onCommit: (v) => send({'percent_control': (v * 100).round()}),
          ),
        ],
      ],
    );
  }
}

/// Fallback for categories without a dedicated panel: every on/off DP.
class GenericControls extends StatelessWidget {
  const GenericControls({required this.device, required this.send, super.key});

  final Device device;
  final SendDps send;

  @override
  Widget build(BuildContext context) {
    final entries = device.state.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Column(
        children: [
          for (final entry in entries)
            if (entry.value is bool)
              SwitchListTile(
                title: Text(entry.key),
                value: entry.value! as bool,
                onChanged: (v) => send({entry.key: v}),
              )
            else
              ListTile(
                title: Text(entry.key),
                trailing: Text('${entry.value}'),
              ),
        ],
      ),
    );
  }
}

/// Slider that only sends a command when the finger lifts.
class _CommitSlider extends StatefulWidget {
  const _CommitSlider({
    required this.value,
    required this.label,
    required this.onCommit,
    this.enabled = true,
  });

  final double value;
  final String Function(double value) label;
  final ValueChanged<double> onCommit;
  final bool enabled;

  @override
  State<_CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<_CommitSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ?? widget.value;
    return Slider(
      value: value,
      label: widget.label(value),
      divisions: 100,
      onChanged: widget.enabled ? (v) => setState(() => _dragging = v) : null,
      onChangeEnd: (v) {
        setState(() => _dragging = null);
        widget.onCommit(v);
      },
    );
  }
}
