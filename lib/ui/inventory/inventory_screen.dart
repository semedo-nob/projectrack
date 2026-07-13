import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/constants/models/inventory_model.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/service/inventory_service.dart';
import 'package:projectrack1/service/unit_service.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/ui/widgets/enterprise_ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _filter = 'all'; // all | low | out

  List<InventoryItem> _applyFilter(List<InventoryItem> items) {
    switch (_filter) {
      case 'low':
        return items.where((i) => i.isLowStock && !i.isOutOfStock).toList();
      case 'out':
        return items.where((i) => i.isOutOfStock).toList();
      default:
        return items;
    }
  }

  InventoryService get _service =>
      InventoryService(context.read<DriftDatabaseProvider>().database);

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InventoryItemSheet(
        projectId: widget.projectId,
        service: _service,
      ),
    );
    if (created == true && mounted) setState(() {});
  }

  Future<void> _logUsage(InventoryItem item) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UsageSheet(item: item, service: _service),
    );
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _editItem(InventoryItem item) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InventoryItemSheet(
        projectId: widget.projectId,
        service: _service,
        existing: item,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showHistory(InventoryItem item) async {
    final history = await _service.getItemHistory(item.id);
    if (!mounted) return;
    final isDark = context.isDarkMode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${item.name} · History',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('No movements yet'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: history.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final m = history[i];
                            final sign =
                                m.kind == MaterialMovementKind.usage ? '−' : '+';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                m.kind == MaterialMovementKind.usage
                                    ? Icons.remove_circle_outline
                                    : Icons.add_circle_outline,
                                color: m.kind.color,
                              ),
                              title: Text(
                                '${m.kind.displayName}  $sign${m.quantityBase.toStringAsFixed(2)} ${m.unitBase}',
                              ),
                              subtitle: Text(
                                DateFormat('MMM d, y · HH:mm').format(m.occurredAt),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final db = context.watch<DriftDatabaseProvider>();
    final service = InventoryService(db.database);

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      appBar: AppBar(
        backgroundColor: EnterpriseUi.appBarBg(isDark),
        title: Text('${widget.projectName} · Inventory'),
        actions: [
          IconButton(
            tooltip: 'Add material',
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Add material'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _chip('all', 'All'),
                _chip('low', 'Low stock'),
                _chip('out', 'Out of stock'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: service.watchProjectInventory(widget.projectId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _applyFilter(snapshot.data!);
                final lowCount =
                    snapshot.data!.where((i) => i.isLowStock || i.isOutOfStock).length;

                if (snapshot.data!.isEmpty) {
                  return _emptyState(isDark);
                }
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No items in this filter',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                     ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length + (lowCount > 0 && _filter == 'all' ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (lowCount > 0 && _filter == 'all' && index == 0) {
                      return _alertBanner(isDark, lowCount);
                    }
                    final item = items[lowCount > 0 && _filter == 'all' ? index - 1 : index];
                    return _InventoryCard(
                      item: item,
                      isDark: isDark,
                      onUse: () => _logUsage(item),
                      onEdit: () => _editItem(item),
                      onHistory: () => _showHistory(item),
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete material?'),
                            content: Text(
                              'Remove “${item.name}” and its history from inventory?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await service.deleteItem(item.id);
                          db.notifyDatabaseChanged();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertBanner(bool isDark, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count material${count == 1 ? '' : 's'} at or below reorder level',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _filter = 'low'),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No inventory yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Purchases from material entries add stock automatically. You can also add materials and log usage here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add material'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppColors.primary.withOpacity(0.18),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primary : null,
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.isDark,
    required this.onUse,
    required this.onEdit,
    required this.onHistory,
    required this.onDelete,
  });

  final InventoryItem item;
  final bool isDark;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: EnterpriseUi.cardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                if (item.isOutOfStock)
                  _badge('Out', AppColors.error)
                else if (item.isLowStock)
                  _badge('Low', AppColors.warning),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'use') {
                      onUse();
                    } else if (v == 'edit') {
                      onEdit();
                    } else if (v == 'history') {
                      onHistory();
                    } else if (v == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'use', child: Text('Log usage')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'history', child: Text('History')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'On hand: ${item.quantityLabel}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            if (item.reorderLevel > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Reorder at ${item.reorderLevel.toStringAsFixed(2)} ${item.unitBase}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onUse,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  label: const Text('Use'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onHistory, child: const Text('History')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InventoryItemSheet extends StatefulWidget {
  const _InventoryItemSheet({
    required this.projectId,
    required this.service,
    this.existing,
  });

  final String projectId;
  final InventoryService service;
  final InventoryItem? existing;

  @override
  State<_InventoryItemSheet> createState() => _InventoryItemSheetState();
}

class _InventoryItemSheetState extends State<_InventoryItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _reorder;
  late final TextEditingController _notes;
  late String _unitId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _reorder = TextEditingController(
      text: e == null ? '0' : e.reorderLevel.toStringAsFixed(
        e.reorderLevel == e.reorderLevel.roundToDouble() ? 0 : 2,
      ),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _unitId = e?.preferredUnitId ??
        UnitService.all
            .firstWhere(
              (u) => u.baseUnit == (e?.unitBase ?? 'kg') && u.toBaseFactor == 1,
              orElse: () => UnitService.byId('u_kg')!,
            )
            .id;
  }

  @override
  void dispose() {
    _name.dispose();
    _reorder.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final unit = UnitService.byId(_unitId) ?? UnitService.byId('u_kg')!;
      final reorder = double.tryParse(_reorder.text.trim()) ?? 0;
      await widget.service.upsertCatalogItem(
        projectId: widget.projectId,
        name: name,
        unitBase: unit.baseUnit,
        preferredUnitId: unit.id,
        reorderLevel: reorder,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        existingId: widget.existing?.id,
      );
      if (!mounted) return;
      context.read<DriftDatabaseProvider>().notifyDatabaseChanged();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Add material' : 'Edit material',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Material name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unitId,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: UnitService.all
                    .map(
                      (u) => DropdownMenuItem(
                        value: u.id,
                        child: Text('${u.displayName} (${u.name})'),
                      ),
                    )
                    .toList(),
                onChanged: widget.existing != null
                    ? null
                    : (v) {
                        if (v != null) setState(() => _unitId = v);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reorder,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Low-stock level (in base unit)',
                  helperText:
                      'Alert when stock ≤ this amount (${UnitService.byId(_unitId)?.baseUnit ?? 'unit'})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.existing == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageSheet extends StatefulWidget {
  const _UsageSheet({required this.item, required this.service});

  final InventoryItem item;
  final InventoryService service;

  @override
  State<_UsageSheet> createState() => _UsageSheetState();
}

class _UsageSheetState extends State<_UsageSheet> {
  final _qty = TextEditingController();
  final _notes = TextEditingController();
  late String _unitId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unitId = widget.item.preferredUnitId ??
        UnitService.all
            .firstWhere(
              (u) =>
                  u.baseUnit == widget.item.unitBase && u.toBaseFactor == 1.0,
              orElse: () => UnitService.byId('u_kg')!,
            )
            .id;
  }

  @override
  void dispose() {
    _qty.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    if (qty <= 0) return;
    setState(() => _saving = true);
    try {
      final unit = UnitService.byId(_unitId) ?? UnitService.byId('u_kg')!;
      await widget.service.recordUsage(
        inventoryItemId: widget.item.id,
        quantityOriginal: qty,
        unit: unit,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      context.read<DriftDatabaseProvider>().notifyDatabaseChanged();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final units = UnitService.all
        .where((u) => u.baseUnit == widget.item.unitBase)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Use ${widget.item.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'On hand: ${widget.item.quantityLabel}',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity used',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: units.any((u) => u.id == _unitId) ? _unitId : units.first.id,
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
              ),
              items: units
                  .map(
                    (u) => DropdownMenuItem(
                      value: u.id,
                      child: Text(u.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _unitId = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Record usage'),
            ),
          ],
        ),
      ),
    );
  }
}
