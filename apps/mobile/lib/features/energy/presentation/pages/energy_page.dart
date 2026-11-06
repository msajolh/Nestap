import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../devices/presentation/providers/home_devices_controller.dart';
import '../../domain/entities/energy_report.dart';
import '../../energy_providers.dart';
import '../widgets/energy_bar_chart.dart';

class EnergyPage extends ConsumerStatefulWidget {
  const EnergyPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  ConsumerState<EnergyPage> createState() => _EnergyPageState();
}

class _EnergyPageState extends ConsumerState<EnergyPage> {
  EnergyRange _range = EnergyRange.week;

  @override
  Widget build(BuildContext context) {
    final query = (deviceId: widget.deviceId, range: _range);
    final report = ref.watch(deviceEnergyProvider(query));
    final device = ref.watch(deviceByIdProvider(widget.deviceId)).value;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(device == null ? 'Energy' : 'Energy · ${device.name}')),
      body: ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<EnergyRange>(
                  segments: const [
                    ButtonSegment(value: EnergyRange.day, label: Text('Day')),
                    ButtonSegment(value: EnergyRange.week, label: Text('Week')),
                    ButtonSegment(value: EnergyRange.month, label: Text('Month')),
                  ],
                  selected: {_range},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: AppSpacing.xl),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 320),
                  child: AsyncValueView(
                    value: report,
                    onRetry: () => ref.invalidate(deviceEnergyProvider(query)),
                    data: (report) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: report.totalKwh.toStringAsFixed(2),
                            style: text.displaySmall?.copyWith(fontWeight: FontWeight.w900),
                            children: [TextSpan(text: ' kWh', style: text.titleLarge)],
                          ),
                        ),
                        Text(
                          switch (_range) {
                            EnergyRange.day => 'Today',
                            EnergyRange.week => 'Last 7 days',
                            EnergyRange.month => 'Last 30 days',
                          },
                          style: text.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: EnergyBarChart(report: report),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: _range == EnergyRange.day ? 'Average per hour' : 'Average per day',
                                value: report.averageKwh,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: _StatCard(label: 'Peak', value: report.peakKwh)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${value.toStringAsFixed(2)} kWh',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
