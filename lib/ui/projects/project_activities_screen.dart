import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/constants/models/activity_model.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/ui/widgets/enterprise_ui.dart';

class ProjectActivitiesScreen extends StatefulWidget {
  const ProjectActivitiesScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<ProjectActivitiesScreen> createState() =>
      _ProjectActivitiesScreenState();
}

class _ProjectActivitiesScreenState extends State<ProjectActivitiesScreen> {
  Future<void> _addActivity() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final byCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    var type = ActivityType.site;
    var occurredAt = DateTime.now();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Log project activity',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'What was done *',
                        hintText: 'e.g. Site clearing, planting, inspection',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ActivityType>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: ActivityType.all
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModal(() => type = v ?? type),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hoursCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Hours spent',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: byCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Performed by',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locCtrl,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'When: ${DateFormat('MMM d, yyyy · HH:mm').format(occurredAt)}',
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: occurredAt,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(occurredAt),
                        );
                        if (!ctx.mounted) return;
                        setModal(() {
                          occurredAt = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t?.hour ?? occurredAt.hour,
                            t?.minute ?? occurredAt.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Save activity'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;
    final db = context.read<DriftDatabaseProvider>();
    final ok = await db.createActivity(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      projectId: widget.projectId,
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      activityType: type.storageValue,
      occurredAt: occurredAt,
      hoursSpent: double.tryParse(hoursCtrl.text.trim()),
      performedBy: byCtrl.text.trim().isEmpty ? null : byCtrl.text.trim(),
      location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Activity logged' : (db.error ?? 'Failed to save')),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final db = context.watch<DriftDatabaseProvider>();

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      appBar: AppBar(
        backgroundColor: EnterpriseUi.appBarBg(isDark),
        title: Text('${widget.projectName} · Activities'),
      ),
      floatingActionButton: EnterpriseUi.primaryFab(
        onPressed: _addActivity,
        icon: Icons.add_rounded,
        tooltip: 'Log activity',
      ),
      body: StreamBuilder<List<ProjectActivity>>(
        stream: db.watchProjectActivities(widget.projectId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 56,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No activities yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Record site work, labour hours, deliveries, and inspections — separate from spend.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = items[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: EnterpriseUi.cardDecoration(isDark),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(a.activityType.icon, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${a.activityType.displayName} · ${DateFormat('MMM d, yyyy · HH:mm').format(a.occurredAt)}'
                            '${a.hoursSpent != null ? ' · ${a.hoursSpent}h' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          if (a.performedBy != null || a.location != null)
                            Text(
                              [
                                if (a.performedBy != null) a.performedBy,
                                if (a.location != null) a.location,
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary,
                              ),
                            ),
                          if (a.description != null &&
                              a.description!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(a.description!),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => db.deleteActivity(a.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
