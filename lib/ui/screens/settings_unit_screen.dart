// lib/ui/screens/settings_unit_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../service/display_unit_prefs.dart';
import '../../service/unit_service.dart';
import '../../themes/app_colors.dart';

class SettingsUnitScreen extends StatefulWidget {
  const SettingsUnitScreen({super.key});

  @override
  State<SettingsUnitScreen> createState() => _SettingsUnitScreenState();
}

class _SettingsUnitScreenState extends State<SettingsUnitScreen> {
  bool _loading = true;
  bool _smartSuggestions = true;
  String _weightId = 'u_kg';
  String _volumeId = 'u_litre';
  String _countId = 'u_piece';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final smart = await DisplayUnitPrefs.smartSuggestionsEnabled();
    final units = await DisplayUnitPrefs.loadAll();
    if (!mounted) return;
    setState(() {
      _smartSuggestions = smart;
      _weightId = DisplayUnitPrefs.validatedDefault('weight', units['weight']);
      _volumeId = DisplayUnitPrefs.validatedDefault('volume', units['volume']);
      _countId = DisplayUnitPrefs.validatedDefault('count', units['count']);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await DisplayUnitPrefs.setSmartSuggestionsEnabled(_smartSuggestions);
    await DisplayUnitPrefs.setDefaultUnitForCategory('weight', _weightId);
    await DisplayUnitPrefs.setDefaultUnitForCategory('volume', _volumeId);
    await DisplayUnitPrefs.setDefaultUnitForCategory('count', _countId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unit settings saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Units & materials'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Choose defaults for new material lines. Smart suggestions use '
                  'these and learn when you pick a unit for a material name.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Smart unit suggestions'),
                  subtitle: const Text(
                    'Show quick-pick units based on what you type (e.g. cement → bag)',
                  ),
                  value: _smartSuggestions,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _smartSuggestions = v),
                ),
                const Divider(height: 32),
                _dropdownTile(
                  isDark: isDark,
                  label: 'Weight',
                  subtitle: 'For sand, cement, nails, etc.',
                  value: _weightId,
                  options: UnitService.forCategory('weight'),
                  onChanged: (id) => setState(() => _weightId = id),
                ),
                const SizedBox(height: 16),
                _dropdownTile(
                  isDark: isDark,
                  label: 'Volume',
                  subtitle: 'For paint, liquids, etc.',
                  value: _volumeId,
                  options: UnitService.forCategory('volume'),
                  onChanged: (id) => setState(() => _volumeId = id),
                ),
                const SizedBox(height: 16),
                _dropdownTile(
                  isDark: isDark,
                  label: 'Count',
                  subtitle: 'For chairs, pieces, packs, etc.',
                  value: _countId,
                  options: UnitService.forCategory('count'),
                  onChanged: (id) => setState(() => _countId = id),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Amounts are stored in base units (kg, litre, piece) for accurate totals. '
                  'Your choices here only change defaults and suggestions.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _dropdownTile({
    required bool isDark,
    required String label,
    required String subtitle,
    required String value,
    required List<UnitOption> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o.id,
                child: Text(o.displayName),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
