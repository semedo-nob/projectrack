// lib/widgets/unit_aware_quantity_field.dart
import 'package:flutter/material.dart';

import '../service/unit_service.dart';
import '../themes/app_colors.dart';

/// Compact chips for smart-picked units (used above quantity on material entry).
class SuggestedUnitChips extends StatelessWidget {
  const SuggestedUnitChips({
    super.key,
    required this.isDark,
    required this.suggestions,
    required this.selectedUnitId,
    required this.onSelect,
  });

  final bool isDark;
  final List<UnitOption> suggestions;
  final String selectedUnitId;
  final ValueChanged<UnitOption> onSelect;

  @override
  Widget build(BuildContext context) {
    if (suggestions.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested units',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in suggestions)
                FilterChip(
                  label: Text(u.displayName),
                  selected: selectedUnitId == u.id,
                  onSelected: (_) => onSelect(u),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontWeight: selectedUnitId == u.id
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selectedUnitId == u.id
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
