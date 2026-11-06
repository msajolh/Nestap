import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/device.dart';
import 'device_visuals.dart';

/// Dashboard card: icon, name, room, status, and a one-tap power button.
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    required this.device,
    required this.onTap,
    this.roomName,
    this.onTogglePower,
    super.key,
  });

  final Device device;
  final String? roomName;
  final VoidCallback onTap;

  /// Null hides the power button (curtains, sensors).
  final ValueChanged<bool>? onTogglePower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = device.online && device.isOn;

    return Semantics(
      button: true,
      label: '${device.name}, ${device.statusLine}',
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: on
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.cyan400.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Opacity(
              opacity: device.online ? 1 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconBadge(icon: device.icon, active: on),
                      const Spacer(),
                      if (onTogglePower != null && device.online)
                        _PowerButton(on: on, onPressed: () => onTogglePower!(!on)),
                      if (!device.online)
                        Icon(Icons.cloud_off_rounded, size: 20, color: scheme.onSurfaceVariant),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [if (roomName != null) roomName!, device.statusLine].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active ? AppColors.activeGradient : null,
        color: active ? null : scheme.surfaceContainer,
      ),
      child: Icon(icon, color: active ? AppColors.navy : scheme.onSurfaceVariant),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        tooltip: on ? 'Turn off' : 'Turn on',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: on ? AppColors.cyan400 : null,
          foregroundColor: on ? AppColors.navy : null,
        ),
        icon: const Icon(Icons.power_settings_new_rounded),
      );
}
