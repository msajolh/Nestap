import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../devices/domain/entities/device.dart';

/// Navy hero card at the top of the dashboard, styled like nestap.net's
/// dark sections.
class HomeSummaryCard extends StatelessWidget {
  const HomeSummaryCard({required this.devices, super.key});

  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final online = devices.where((d) => d.online).length;
    final on = devices.where((d) => d.online && d.isOn).length;
    final watts = devices
        .where((d) => d.online && d.isOn)
        .fold<double>(0, (sum, d) => sum + (d.powerW ?? 0));

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.all(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Wrap(
          spacing: AppSpacing.xxl,
          runSpacing: AppSpacing.lg,
          children: [
            _Stat(value: '$on', label: on == 1 ? 'device on' : 'devices on', style: text),
            _Stat(value: '$online/${devices.length}', label: 'online', style: text),
            _Stat(value: watts.toStringAsFixed(0), unit: 'W', label: 'using now', style: text),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.style, this.unit});

  final String value;
  final String? unit;
  final String label;
  final TextTheme style;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: value,
              style: style.headlineMedium?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w900,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: style.titleMedium?.copyWith(color: AppColors.cyan200),
                  ),
              ],
            ),
          ),
          Text(label, style: style.bodyMedium?.copyWith(color: AppColors.gray300)),
        ],
      );
}
