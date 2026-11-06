/// Small date/time formatters (English). Replace with `intl` + ARB files when
/// the app is localised.
abstract final class Formatters {
  static const weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String two(int n) => n.toString().padLeft(2, '0');

  /// 07:30
  static String time(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

  /// Today / Yesterday / Mon 3 Nov
  static String day(DateTime t, {DateTime? now}) {
    final today = _date(now ?? DateTime.now());
    final date = _date(t);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${weekdaysShort[t.weekday - 1]} ${t.day} ${monthsShort[t.month - 1]}';
  }

  /// Repeat days (1 = Monday … 7 = Sunday) as people say them.
  static String days(List<int> days) {
    final set = days.toSet();
    if (set.isEmpty) return 'Once';
    if (set.length == 7) return 'Every day';
    if (set.length == 5 && set.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
    if (set.length == 2 && set.containsAll({6, 7})) return 'Weekends';
    final sorted = set.toList()..sort();
    return sorted.map((d) => weekdaysShort[d - 1]).join(', ');
  }

  static DateTime _date(DateTime t) => DateTime(t.year, t.month, t.day);
}
