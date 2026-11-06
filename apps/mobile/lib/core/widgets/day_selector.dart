import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Seven round M–S toggles. Days are 1 (Monday) … 7 (Sunday).
class DaySelector extends StatelessWidget {
  const DaySelector({required this.selected, required this.onChanged, super.key});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Each day gets an equal slot; circles shrink below 40 px on narrow phones.
    return Row(
      children: [
        for (var day = 1; day <= 7; day++)
          Expanded(
            child: Center(
              child: Semantics(
                button: true,
                selected: selected.contains(day),
                label: Formatters.weekdaysShort[day - 1],
                child: InkResponse(
                  radius: 24,
                  onTap: () {
                    final next = {...selected};
                    if (!next.remove(day)) next.add(day);
                    onChanged(next);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected.contains(day) ? AppColors.cyan400 : scheme.surfaceContainer,
                    ),
                    child: Text(
                      Formatters.weekdayLetters[day - 1],
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected.contains(day) ? AppColors.navy : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
