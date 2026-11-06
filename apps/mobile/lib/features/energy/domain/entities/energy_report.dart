import 'package:equatable/equatable.dart';

enum EnergyRange { day, week, month }

class EnergyPoint extends Equatable {
  const EnergyPoint({required this.start, required this.kwh});

  /// Start of the bucket (hour for [EnergyRange.day], day otherwise), local time.
  final DateTime start;
  final double kwh;

  @override
  List<Object?> get props => [start, kwh];
}

class EnergyReport extends Equatable {
  const EnergyReport({required this.range, required this.totalKwh, required this.points});

  final EnergyRange range;
  final double totalKwh;
  final List<EnergyPoint> points;

  double get peakKwh => points.fold<double>(0, (peak, p) => p.kwh > peak ? p.kwh : peak);

  /// Average over buckets that have started (future hours of today are 0).
  double get averageKwh {
    final now = DateTime.now();
    final elapsed = points.where((p) => !p.start.isAfter(now)).toList();
    if (elapsed.isEmpty) return 0;
    return elapsed.fold<double>(0, (sum, p) => sum + p.kwh) / elapsed.length;
  }

  @override
  List<Object?> get props => [range, totalKwh, points];
}
