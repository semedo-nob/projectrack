// lib/database/database.dart
import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ===== TABLE DEFINITIONS =====

class Users extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get name => text()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();

  /// Logged-in user who owns this project (isolates data per account).
  TextColumn get ownerId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  RealColumn get budget => real()();
  RealColumn get spent => real().withDefault(const Constant(0.0))();
  TextColumn get status => text()();
  TextColumn get category => text()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get merchant => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptImage => text().nullable()();
  TextColumn get status => text()();
  /// User-entered quantity in [unitOriginal] (e.g. 2 bags).
  RealColumn get quantityOriginal => real().nullable()();
  /// Unit id/slug from [UnitDefs] (e.g. bag, kg).
  TextColumn get unitOriginal => text().nullable()();
  /// Quantity normalized to category base (kg, litre, piece).
  RealColumn get quantityBase => real().nullable()();
  TextColumn get unitBase => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Predefined measurement units (weight / volume / count).
@DataClassName('UnitDefRow')
class UnitDefs extends Table {
  @override
  String get tableName => 'units';

  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get name => text()();
  TextColumn get displayName => text()();
  TextColumn get category => text()();
  RealColumn get toBaseFactor => real()();
  TextColumn get baseUnit => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()();
  TextColumn get priority => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get assignedTo => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Receipts extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get expenseId => text().references(Expenses, #id)();
  TextColumn get imageUrl => text()();
  TextColumn get ocrData => text().nullable()();
  RealColumn get confidence => real().nullable()();
  DateTimeColumn get processedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  RealColumn get budget => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text().withLength(min: 1, max: 50)();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

class ProjectTags extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {projectId, tag};
}

/// Per-project material stock (quantities stored in category base units).
@DataClassName('InventoryItemRow')
class InventoryItems extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get name => text()();
  /// Lowercase trimmed name for purchase→stock matching.
  TextColumn get nameKey => text()();
  RealColumn get quantityBase => real().withDefault(const Constant(0.0))();
  TextColumn get unitBase => text()();
  /// Preferred display unit id (e.g. u_bag).
  TextColumn get preferredUnitId => text().nullable()();
  /// Low-stock threshold in [unitBase].
  RealColumn get reorderLevel => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Purchase / usage / adjustment ledger for inventory.
@DataClassName('MaterialUsageRow')
class MaterialUsages extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get inventoryItemId => text().references(InventoryItems, #id)();
  /// purchase | usage | adjustment
  TextColumn get kind => text()();
  RealColumn get quantityBase => real()();
  TextColumn get unitBase => text()();
  RealColumn get quantityOriginal => real().nullable()();
  TextColumn get unitOriginal => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get expenseId => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Non-financial project activity / work log (who did what, hours, notes).
@DataClassName('ActivityLogRow')
class ActivityLogs extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  /// labour | site | delivery | inspection | other
  TextColumn get activityType => text().withDefault(const Constant('other'))();
  DateTimeColumn get occurredAt => dateTime()();
  RealColumn get hoursSpent => real().nullable()();
  TextColumn get performedBy => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get linkedExpenseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Project milestones / phases for schedule adherence.
@DataClassName('ProjectMilestoneRow')
class ProjectMilestones extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  /// pending | done | skipped
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ===== DATABASE CLASS =====

@DriftDatabase(
  tables: [
    Projects,
    Expenses,
    UnitDefs,
    Tasks,
    Receipts,
    Categories,
    Settings,
    Users,
    ProjectTags,
    InventoryItems,
    MaterialUsages,
    ActivityLogs,
    ProjectMilestones,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Insert default categories
        await batch((batch) {
          final now = DateTime.now();
          batch.insertAll(categories, [
            CategoriesCompanion.insert(
              id: '1',
              name: 'Construction Materials',
              color: const Value('#5A4FCF'),
              icon: const Value('construction'),
              createdAt: now,
            ),
            CategoriesCompanion.insert(
              id: '2',
              name: 'Labor',
              color: const Value('#7C6FF2'),
              icon: const Value('handyman'),
              createdAt: now,
            ),
            CategoriesCompanion.insert(
              id: '3',
              name: 'Equipment Rental',
              color: const Value('#9D8FF5'),
              icon: const Value('precision_manufacturing'),
              createdAt: now,
            ),
            CategoriesCompanion.insert(
              id: '4',
              name: 'Permits & Fees',
              color: const Value('#3F36A0'),
              icon: const Value('description'),
              createdAt: now,
            ),
            CategoriesCompanion.insert(
              id: '5',
              name: 'Travel',
              color: const Value('#F59E0B'),
              icon: const Value('directions_car'),
              createdAt: now,
            ),
            CategoriesCompanion.insert(
              id: '6',
              name: 'Office Supplies',
              color: const Value('#2E9A6A'),
              icon: const Value('inventory'),
              createdAt: now,
            ),
            CategoriesCompanion.insert(
              id: '7',
              name: 'Marketing',
              color: const Value('#E53E3E'),
              icon: const Value('campaign'),
              createdAt: now,
            ),
          ]);
        });

        await batch((batch) {
          void insertUnit({
            required String id,
            required String name,
            required String displayName,
            required String category,
            required double toBaseFactor,
            required String baseUnit,
          }) {
            batch.insert(
              unitDefs,
              UnitDefsCompanion.insert(
                id: id,
                name: name,
                displayName: displayName,
                category: category,
                toBaseFactor: toBaseFactor,
                baseUnit: baseUnit,
              ),
            );
          }

          insertUnit(
            id: 'u_kg',
            name: 'kg',
            displayName: 'Kilogram',
            category: 'weight',
            toBaseFactor: 1.0,
            baseUnit: 'kg',
          );
          insertUnit(
            id: 'u_g',
            name: 'g',
            displayName: 'Gram',
            category: 'weight',
            toBaseFactor: 0.001,
            baseUnit: 'kg',
          );
          insertUnit(
            id: 'u_bag',
            name: 'bag',
            displayName: 'Bag',
            category: 'weight',
            toBaseFactor: 50.0,
            baseUnit: 'kg',
          );
          insertUnit(
            id: 'u_tonne',
            name: 'tonne',
            displayName: 'Tonne',
            category: 'weight',
            toBaseFactor: 1000.0,
            baseUnit: 'kg',
          );
          insertUnit(
            id: 'u_litre',
            name: 'litre',
            displayName: 'Litre',
            category: 'volume',
            toBaseFactor: 1.0,
            baseUnit: 'litre',
          );
          insertUnit(
            id: 'u_ml',
            name: 'ml',
            displayName: 'Millilitre',
            category: 'volume',
            toBaseFactor: 0.001,
            baseUnit: 'litre',
          );
          insertUnit(
            id: 'u_gallon',
            name: 'gallon',
            displayName: 'Gallon (US)',
            category: 'volume',
            toBaseFactor: 3.785,
            baseUnit: 'litre',
          );
          insertUnit(
            id: 'u_piece',
            name: 'piece',
            displayName: 'Piece',
            category: 'count',
            toBaseFactor: 1.0,
            baseUnit: 'piece',
          );
          insertUnit(
            id: 'u_dozen',
            name: 'dozen',
            displayName: 'Dozen',
            category: 'count',
            toBaseFactor: 12.0,
            baseUnit: 'piece',
          );
          insertUnit(
            id: 'u_pack',
            name: 'pack',
            displayName: 'Pack',
            category: 'count',
            toBaseFactor: 6.0,
            baseUnit: 'piece',
          );
        });
        await _seedExpandedUnits();
        await _seedAgricultureUnits();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(projects, projects.ownerId);
          await customStatement(
            'UPDATE projects SET owner_id = '
            '(SELECT id FROM users ORDER BY created_at ASC LIMIT 1) '
            'WHERE owner_id IS NULL',
          );
        }
        if (from < 3) {
          await m.createTable(unitDefs);
          await batch((batch) {
            void insertUnit({
              required String id,
              required String name,
              required String displayName,
              required String category,
              required double toBaseFactor,
              required String baseUnit,
            }) {
              batch.insert(
                unitDefs,
                UnitDefsCompanion.insert(
                  id: id,
                  name: name,
                  displayName: displayName,
                  category: category,
                  toBaseFactor: toBaseFactor,
                  baseUnit: baseUnit,
                ),
              );
            }

            insertUnit(
              id: 'u_kg',
              name: 'kg',
              displayName: 'Kilogram',
              category: 'weight',
              toBaseFactor: 1.0,
              baseUnit: 'kg',
            );
            insertUnit(
              id: 'u_g',
              name: 'g',
              displayName: 'Gram',
              category: 'weight',
              toBaseFactor: 0.001,
              baseUnit: 'kg',
            );
            insertUnit(
              id: 'u_bag',
              name: 'bag',
              displayName: 'Bag',
              category: 'weight',
              toBaseFactor: 50.0,
              baseUnit: 'kg',
            );
            insertUnit(
              id: 'u_tonne',
              name: 'tonne',
              displayName: 'Tonne',
              category: 'weight',
              toBaseFactor: 1000.0,
              baseUnit: 'kg',
            );
            insertUnit(
              id: 'u_litre',
              name: 'litre',
              displayName: 'Litre',
              category: 'volume',
              toBaseFactor: 1.0,
              baseUnit: 'litre',
            );
            insertUnit(
              id: 'u_ml',
              name: 'ml',
              displayName: 'Millilitre',
              category: 'volume',
              toBaseFactor: 0.001,
              baseUnit: 'litre',
            );
            insertUnit(
              id: 'u_gallon',
              name: 'gallon',
              displayName: 'Gallon (US)',
              category: 'volume',
              toBaseFactor: 3.785,
              baseUnit: 'litre',
            );
            insertUnit(
              id: 'u_piece',
              name: 'piece',
              displayName: 'Piece',
              category: 'count',
              toBaseFactor: 1.0,
              baseUnit: 'piece',
            );
            insertUnit(
              id: 'u_dozen',
              name: 'dozen',
              displayName: 'Dozen',
              category: 'count',
              toBaseFactor: 12.0,
              baseUnit: 'piece',
            );
            insertUnit(
              id: 'u_pack',
              name: 'pack',
              displayName: 'Pack',
              category: 'count',
              toBaseFactor: 6.0,
              baseUnit: 'piece',
            );
          });
          await m.addColumn(expenses, expenses.quantityOriginal);
          await m.addColumn(expenses, expenses.unitOriginal);
          await m.addColumn(expenses, expenses.quantityBase);
          await m.addColumn(expenses, expenses.unitBase);
        }
        if (from < 4) {
          await m.createTable(inventoryItems);
          await m.createTable(materialUsages);
        }
        if (from < 5) {
          await _seedExpandedUnits();
        }
        if (from < 6) {
          await m.createTable(activityLogs);
          await m.createTable(projectMilestones);
          await _seedAgricultureUnits();
        }
      },
    );
  }

  Future<void> _seedAgricultureUnits() async {
    Future<void> upsert({
      required String id,
      required String name,
      required String displayName,
      required String category,
      required double toBaseFactor,
      required String baseUnit,
    }) async {
      await into(unitDefs).insertOnConflictUpdate(
        UnitDefsCompanion.insert(
          id: id,
          name: name,
          displayName: displayName,
          category: category,
          toBaseFactor: toBaseFactor,
          baseUnit: baseUnit,
        ),
      );
    }

    await upsert(
      id: 'u_acre',
      name: 'acre',
      displayName: 'Acre',
      category: 'area',
      toBaseFactor: 4046.86,
      baseUnit: 'm2',
    );
    await upsert(
      id: 'u_hectare',
      name: 'hectare',
      displayName: 'Hectare',
      category: 'area',
      toBaseFactor: 10000.0,
      baseUnit: 'm2',
    );
    await upsert(
      id: 'u_crate',
      name: 'crate',
      displayName: 'Crate',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    );
  }

  Future<void> _seedExpandedUnits() async {
    Future<void> upsert({
      required String id,
      required String name,
      required String displayName,
      required String category,
      required double toBaseFactor,
      required String baseUnit,
    }) async {
      await into(unitDefs).insertOnConflictUpdate(
        UnitDefsCompanion.insert(
          id: id,
          name: name,
          displayName: displayName,
          category: category,
          toBaseFactor: toBaseFactor,
          baseUnit: baseUnit,
        ),
      );
    }

    await upsert(
      id: 'u_m3',
      name: 'm3',
      displayName: 'Cubic metre',
      category: 'volume',
      toBaseFactor: 1000.0,
      baseUnit: 'litre',
    );
    await upsert(
      id: 'u_box',
      name: 'box',
      displayName: 'Box',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    );
    await upsert(
      id: 'u_set',
      name: 'set',
      displayName: 'Set',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    );
    await upsert(
      id: 'u_bundle',
      name: 'bundle',
      displayName: 'Bundle',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    );
    await upsert(
      id: 'u_roll',
      name: 'roll',
      displayName: 'Roll',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    );
    await upsert(
      id: 'u_sheet',
      name: 'sheet',
      displayName: 'Sheet',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    );
    await upsert(
      id: 'u_load',
      name: 'load',
      displayName: 'Load / Trip',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    );
    await upsert(
      id: 'u_m',
      name: 'm',
      displayName: 'Metre',
      category: 'length',
      toBaseFactor: 1.0,
      baseUnit: 'm',
    );
    await upsert(
      id: 'u_cm',
      name: 'cm',
      displayName: 'Centimetre',
      category: 'length',
      toBaseFactor: 0.01,
      baseUnit: 'm',
    );
    await upsert(
      id: 'u_ft',
      name: 'ft',
      displayName: 'Foot',
      category: 'length',
      toBaseFactor: 0.3048,
      baseUnit: 'm',
    );
    await upsert(
      id: 'u_m2',
      name: 'm2',
      displayName: 'Square metre',
      category: 'area',
      toBaseFactor: 1.0,
      baseUnit: 'm2',
    );
    await upsert(
      id: 'u_hour',
      name: 'hour',
      displayName: 'Hour',
      category: 'time',
      toBaseFactor: 1.0,
      baseUnit: 'hour',
    );
    await upsert(
      id: 'u_day',
      name: 'day',
      displayName: 'Day',
      category: 'time',
      toBaseFactor: 8.0,
      baseUnit: 'hour',
    );
  }

  // ===== PROJECT QUERIES =====

  Future<List<Project>> getAllProjects() => select(projects).get();

  Stream<List<Project>> watchAllProjects() => select(projects).watch();

  Future<List<Project>> getProjectsForUser(String userId) {
    return (select(projects)
          ..where((t) => t.ownerId.equals(userId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Stream<List<Project>> watchProjectsForUser(String userId) {
    return (select(projects)
          ..where((t) => t.ownerId.equals(userId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<Project?> getProject(String id) {
    return (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Project?> getProjectForUser(String id, String userId) {
    return (select(projects)
          ..where((t) => t.id.equals(id) & t.ownerId.equals(userId)))
        .getSingleOrNull();
  }

  Future<List<String>> getProjectTags(String projectId) async {
    final rows =
        await (select(projectTags)..where((t) => t.projectId.equals(projectId))).get();
    return rows.map((row) => row.tag).toList()..sort();
  }

  Future<Map<String, List<String>>> getTagsForProjects(List<String> projectIds) async {
    if (projectIds.isEmpty) return {};
    final rows =
        await (select(projectTags)..where((t) => t.projectId.isIn(projectIds))).get();
    final map = <String, List<String>>{};
    for (final row in rows) {
      map.putIfAbsent(row.projectId, () => <String>[]).add(row.tag);
    }
    for (final tags in map.values) {
      tags.sort();
    }
    return map;
  }

  Future<void> replaceProjectTags(String projectId, List<String> tags) async {
    final normalized = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    await transaction(() async {
      await (delete(projectTags)..where((t) => t.projectId.equals(projectId))).go();
      if (normalized.isEmpty) return;
      await batch((batch) {
        batch.insertAll(
          projectTags,
          normalized
              .map(
                (tag) => ProjectTagsCompanion.insert(
                  projectId: projectId,
                  tag: tag,
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<int> insertProject(ProjectsCompanion project) {
    return into(projects).insert(project);
  }

  Future<bool> updateProject(ProjectsCompanion project) {
    return update(projects).replace(project);
  }

  Future<int> deleteProject(String id) {
    return (delete(projects)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes expenses (and their receipts), tasks, tags, then the project row.
  Future<void> deleteProjectCascade(String projectId) async {
    await transaction(() async {
      final expenseRows = await (select(
        expenses,
      )..where((t) => t.projectId.equals(projectId))).get();
      for (final e in expenseRows) {
        await (delete(receipts)..where((r) => r.expenseId.equals(e.id))).go();
      }
      await (delete(
        expenses,
      )..where((t) => t.projectId.equals(projectId))).go();
      await (delete(tasks)..where((t) => t.projectId.equals(projectId))).go();
      await (delete(
        activityLogs,
      )..where((t) => t.projectId.equals(projectId))).go();
      await (delete(
        projectMilestones,
      )..where((t) => t.projectId.equals(projectId))).go();
      await (delete(
        materialUsages,
      )..where((t) => t.projectId.equals(projectId))).go();
      await (delete(
        inventoryItems,
      )..where((t) => t.projectId.equals(projectId))).go();
      await (delete(
        projectTags,
      )..where((t) => t.projectId.equals(projectId))).go();
      await (delete(projects)..where((t) => t.id.equals(projectId))).go();
    });
  }

  /// Deletes all projects (and related rows) owned by [userId]. Used before full restore.
  Future<void> wipeUserDataForRestore(String userId) async {
    final rows =
        await (select(projects)..where((t) => t.ownerId.equals(userId))).get();
    for (final p in rows) {
      await deleteProjectCascade(p.id);
    }
  }

  Future<List<UnitDefRow>> getAllUnits() =>
      (select(unitDefs)..orderBy([(t) => OrderingTerm.asc(t.category)])).get();

  Future<List<Project>> searchProjects(String query, String userId) async {
    final q = query.trim().toLowerCase();
    final rows =
        await (select(projects)
              ..where((t) => t.ownerId.equals(userId))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    if (q.isEmpty) return rows;
    return rows
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();
  }

  // ===== EXPENSE QUERIES =====

  Future<List<Expense>> getExpensesByProject(String projectId) {
    return (select(expenses)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Stream<List<Expense>> watchExpensesByProject(String projectId) {
    return (select(expenses)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<Expense?> getExpense(String id) {
    return (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertExpense(ExpensesCompanion expense) async {
    return await transaction(() async {
      final result = await into(expenses).insert(expense);
      final projectId = expense.projectId.value;
      await _updateProjectSpentAndProgress(projectId);
      return result;
    });
  }

  Future<bool> updateExpense(ExpensesCompanion expense) async {
    return await transaction(() async {
      final result = await update(expenses).replace(expense);
      final projectId = expense.projectId.value;
      await _updateProjectSpentAndProgress(projectId);
      return result;
    });
  }

  Future<int> deleteExpense(String id) async {
    final expense = await getExpense(id);
    if (expense == null) return 0;
    final projectId = expense.projectId;

    return await transaction(() async {
      await (delete(receipts)..where((t) => t.expenseId.equals(id))).go();
      final result = await (delete(
        expenses,
      )..where((t) => t.id.equals(id))).go();
      await _updateProjectSpentAndProgress(projectId);
      return result;
    });
  }

  Future<void> insertReceiptRecord({
    required String id,
    required String expenseId,
    required String imageUrl,
    String? ocrData,
    double? confidence,
    DateTime? processedAt,
  }) async {
    await into(receipts).insertOnConflictUpdate(
      ReceiptsCompanion(
        id: Value(id),
        expenseId: Value(expenseId),
        imageUrl: Value(imageUrl),
        ocrData: Value(ocrData),
        confidence: Value(confidence),
        processedAt: Value(processedAt ?? DateTime.now()),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Receipt>> getReceiptsForExpense(String expenseId) async {
    return (select(receipts)..where((t) => t.expenseId.equals(expenseId))).get();
  }

  Future<void> _updateProjectSpentAndProgress(String projectId) async {
    final totalSpent = await _getProjectTotalSpent(projectId);
    final project = await getProject(projectId);
    if (project == null) return;
    final budget = project.budget;
    final progress = budget > 0 ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    await (update(projects)..where((t) => t.id.equals(projectId))).write(
      ProjectsCompanion(
        spent: Value(totalSpent),
        progress: Value(progress),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<double> _getProjectTotalSpent(String projectId) async {
    final list =
        await (select(expenses)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([]))
            .map((e) => e.amount)
            .get();
    return list.fold<double>(0.0, (double sum, double amount) => sum + amount);
  }

  // ===== TASK QUERIES =====

  Future<List<Task>> getTasksByProject(String projectId) {
    return (select(tasks)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Total tasks across the given projects (for profile, analytics).
  Future<int> countTasksForProjects(List<String> projectIds) async {
    if (projectIds.isEmpty) return 0;
    final rows = await (select(
      tasks,
    )..where((t) => t.projectId.isIn(projectIds))).get();
    return rows.length;
  }

  Stream<List<Task>> watchTasksByProject(String projectId) {
    return (select(tasks)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<Task?> getTask(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);

  Future<bool> updateTask(TasksCompanion task) => update(tasks).replace(task);

  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // ===== ACTIVITY LOG QUERIES =====

  Stream<List<ActivityLogRow>> watchActivityLogs(String projectId) {
    return (select(activityLogs)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<ActivityLogRow>> getActivityLogs(String projectId) {
    return (select(activityLogs)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<int> insertActivityLog(ActivityLogsCompanion row) =>
      into(activityLogs).insert(row);

  Future<bool> updateActivityLog(ActivityLogsCompanion row) =>
      update(activityLogs).replace(row);

  Future<int> deleteActivityLog(String id) =>
      (delete(activityLogs)..where((t) => t.id.equals(id))).go();

  // ===== MILESTONE QUERIES =====

  Stream<List<ProjectMilestoneRow>> watchMilestones(String projectId) {
    return (select(projectMilestones)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<List<ProjectMilestoneRow>> getMilestones(String projectId) {
    return (select(projectMilestones)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<ProjectMilestoneRow?> getMilestone(String id) {
    return (select(projectMilestones)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertMilestone(ProjectMilestonesCompanion row) =>
      into(projectMilestones).insert(row);

  Future<bool> updateMilestone(ProjectMilestonesCompanion row) =>
      update(projectMilestones).replace(row);

  Future<int> deleteMilestone(String id) =>
      (delete(projectMilestones)..where((t) => t.id.equals(id))).go();

  // ===== INVENTORY QUERIES =====

  Stream<List<InventoryItemRow>> watchInventoryForProject(String projectId) {
    return (select(inventoryItems)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<InventoryItemRow>> getInventoryForProject(String projectId) {
    return (select(inventoryItems)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<InventoryItemRow?> getInventoryItem(String id) {
    return (select(
      inventoryItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<InventoryItemRow?> findInventoryByNameKey(
    String projectId,
    String nameKey,
  ) {
    return (select(inventoryItems)..where(
          (t) => t.projectId.equals(projectId) & t.nameKey.equals(nameKey),
        ))
        .getSingleOrNull();
  }

  Future<int> insertInventoryItem(InventoryItemsCompanion row) =>
      into(inventoryItems).insert(row);

  Future<bool> updateInventoryItem(InventoryItemsCompanion row) =>
      update(inventoryItems).replace(row);

  Future<int> deleteInventoryItem(String id) async {
    await (delete(
      materialUsages,
    )..where((t) => t.inventoryItemId.equals(id))).go();
    return (delete(inventoryItems)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<MaterialUsageRow>> watchUsagesForProject(String projectId) {
    return (select(materialUsages)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<MaterialUsageRow>> getUsagesForItem(String inventoryItemId) {
    return (select(materialUsages)
          ..where((t) => t.inventoryItemId.equals(inventoryItemId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<int> insertMaterialUsage(MaterialUsagesCompanion row) =>
      into(materialUsages).insert(row);

  // ===== DASHBOARD STATS =====

  Future<Map<String, dynamic>> getDashboardStats() async {
    final projectCount = await (select(
      projects,
    ).map((p) => p.id).get()).then((ids) => ids.length);

    final totalBudget = await (select(projects).map((p) => p.budget).get())
        .then((budgets) => budgets.fold(0.0, (a, b) => a + b));

    final totalSpent = await (select(projects).map((p) => p.spent).get()).then(
      (spent) => spent.fold(0.0, (a, b) => a + b),
    );

    final pendingTasks =
        await (select(tasks)..where((t) => t.status.equals('done').not()))
            .get()
            .then((tasks) => tasks.length);

    return {
      'projectCount': projectCount,
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
      'remainingBudget': totalBudget - totalSpent,
      'pendingTasks': pendingTasks,
    };
  }

  Future<Map<String, dynamic>> getDashboardStatsForUser(String userId) async {
    final projectRows = await (select(
      projects,
    )..where((t) => t.ownerId.equals(userId))).get();
    final projectIds = projectRows.map((p) => p.id).toList();
    final projectCount = projectIds.length;

    final totalBudget = projectRows.fold<double>(0.0, (a, p) => a + p.budget);

    var totalSpent = 0.0;
    var pendingTasks = 0;
    if (projectIds.isNotEmpty) {
      final expenseRows = await (select(
        expenses,
      )..where((t) => t.projectId.isIn(projectIds))).get();
      totalSpent = expenseRows.fold<double>(0.0, (a, e) => a + e.amount);

      pendingTasks =
          await (select(tasks)..where(
                (t) =>
                    t.projectId.isIn(projectIds) &
                    t.status.equals('done').not(),
              ))
              .get()
              .then((rows) => rows.length);
    }

    return {
      'projectCount': projectCount,
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
      'remainingBudget': totalBudget - totalSpent,
      'pendingTasks': pendingTasks,
    };
  }

  /// Emits whenever projects, tasks, or expenses change for [userId]'s data.
  /// Uses table watches (not polling) so the dashboard stays fresh without timers.
  Stream<void> watchDashboardTriggersForUser(String userId) {
    late StreamController<void> controller;
    StreamSubscription<List<Project>>? projectSub;
    StreamSubscription<List<Task>>? taskSub;
    StreamSubscription<List<Expense>>? expenseSub;

    void ping() {
      if (!controller.isClosed) {
        controller.add(null);
      }
    }

    controller = StreamController<void>.broadcast(
      onListen: () {
        projectSub = watchProjectsForUser(userId).listen((_) => ping());
        taskSub = select(tasks).watch().listen((_) => ping());
        expenseSub = select(expenses).watch().listen((_) => ping());
        ping();
      },
      onCancel: () async {
        await projectSub?.cancel();
        await taskSub?.cancel();
        await expenseSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<Expense>> watchExpensesForProjects(List<String> projectIds) {
    if (projectIds.isEmpty) {
      return Stream.value(const <Expense>[]);
    }
    return (select(expenses)..where((t) => t.projectId.isIn(projectIds))).watch();
  }

  // ===== USER QUERIES =====

  Future<User?> getUser(String id) {
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<User?> getUserByEmail(String email) {
    return (select(
      users,
    )..where((t) => t.email.equals(email))).getSingleOrNull();
  }

  Future<int> insertUser(UsersCompanion user) {
    return into(users).insert(user);
  }

  Future<bool> updateUser(UsersCompanion user) {
    return update(users).replace(user);
  }

  Future<int> deleteUser(String id) {
    return (delete(users)..where((t) => t.id.equals(id))).go();
  }

  // ===== BACKUP / RESTORE =====

  Future<Map<String, dynamic>> exportUserBackup(String userId) async {
    final user = await getUser(userId);
    final projectRows = await (select(
      projects,
    )..where((t) => t.ownerId.equals(userId))).get();
    final projectIds = projectRows.map((p) => p.id).toList();

    final expenseRows = projectIds.isEmpty
        ? <Expense>[]
        : await (select(
            expenses,
          )..where((t) => t.projectId.isIn(projectIds))).get();
    final taskRows = projectIds.isEmpty
        ? <Task>[]
        : await (select(
            tasks,
          )..where((t) => t.projectId.isIn(projectIds))).get();
    final tagRows = projectIds.isEmpty
        ? <ProjectTag>[]
        : await (select(
            projectTags,
          )..where((t) => t.projectId.isIn(projectIds))).get();
    final expenseIds = expenseRows.map((e) => e.id).toList();
    final receiptRows = expenseIds.isEmpty
        ? <Receipt>[]
        : await (select(
            receipts,
          )..where((t) => t.expenseId.isIn(expenseIds))).get();
    final activityRows = projectIds.isEmpty
        ? <ActivityLogRow>[]
        : await (select(
            activityLogs,
          )..where((t) => t.projectId.isIn(projectIds))).get();
    final milestoneRows = projectIds.isEmpty
        ? <ProjectMilestoneRow>[]
        : await (select(
            projectMilestones,
          )..where((t) => t.projectId.isIn(projectIds))).get();

    return {
      'schemaVersion': schemaVersion,
      'generatedAt': DateTime.now().toIso8601String(),
      'user': user == null
          ? null
          : {
              'id': user.id,
              'name': user.name,
              'email': user.email,
              'passwordHash': user.passwordHash,
              'avatarUrl': user.avatarUrl,
              'createdAt': user.createdAt.toIso8601String(),
              'updatedAt': user.updatedAt.toIso8601String(),
            },
      'projects': projectRows
          .map(
            (p) => {
              'id': p.id,
              'ownerId': p.ownerId,
              'name': p.name,
              'description': p.description,
              'startDate': p.startDate.toIso8601String(),
              'endDate': p.endDate?.toIso8601String(),
              'budget': p.budget,
              'spent': p.spent,
              'status': p.status,
              'category': p.category,
              'progress': p.progress,
              'imageUrl': p.imageUrl,
              'createdAt': p.createdAt.toIso8601String(),
              'updatedAt': p.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'expenses': expenseRows
          .map(
            (e) => {
              'id': e.id,
              'projectId': e.projectId,
              'merchant': e.merchant,
              'amount': e.amount,
              'date': e.date.toIso8601String(),
              'category': e.category,
              'notes': e.notes,
              'receiptImage': e.receiptImage,
              'status': e.status,
              'quantityOriginal': e.quantityOriginal,
              'unitOriginal': e.unitOriginal,
              'quantityBase': e.quantityBase,
              'unitBase': e.unitBase,
              'createdAt': e.createdAt.toIso8601String(),
              'updatedAt': e.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'tasks': taskRows
          .map(
            (t) => {
              'id': t.id,
              'projectId': t.projectId,
              'title': t.title,
              'description': t.description,
              'status': t.status,
              'priority': t.priority,
              'dueDate': t.dueDate?.toIso8601String(),
              'assignedTo': t.assignedTo,
              'createdAt': t.createdAt.toIso8601String(),
              'updatedAt': t.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'receipts': receiptRows
          .map(
            (r) => {
              'id': r.id,
              'expenseId': r.expenseId,
              'imageUrl': r.imageUrl,
              'ocrData': r.ocrData,
              'confidence': r.confidence,
              'processedAt': r.processedAt?.toIso8601String(),
              'createdAt': r.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'projectTags': tagRows
          .map((tag) => {'projectId': tag.projectId, 'tag': tag.tag})
          .toList(),
      'activityLogs': activityRows
          .map(
            (a) => {
              'id': a.id,
              'projectId': a.projectId,
              'title': a.title,
              'description': a.description,
              'activityType': a.activityType,
              'occurredAt': a.occurredAt.toIso8601String(),
              'hoursSpent': a.hoursSpent,
              'performedBy': a.performedBy,
              'location': a.location,
              'linkedExpenseId': a.linkedExpenseId,
              'createdAt': a.createdAt.toIso8601String(),
              'updatedAt': a.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'milestones': milestoneRows
          .map(
            (m) => {
              'id': m.id,
              'projectId': m.projectId,
              'title': m.title,
              'description': m.description,
              'dueDate': m.dueDate?.toIso8601String(),
              'status': m.status,
              'sortOrder': m.sortOrder,
              'completedAt': m.completedAt?.toIso8601String(),
              'createdAt': m.createdAt.toIso8601String(),
              'updatedAt': m.updatedAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<void> importUserBackup(
    Map<String, dynamic> backup, {
    required String userId,
  }) async {
    await transaction(() async {
      final userJson = backup['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        await into(users).insertOnConflictUpdate(
          UsersCompanion(
            id: Value(userId),
            name: Value(userJson['name'] as String? ?? 'User'),
            email: Value(userJson['email'] as String? ?? ''),
            passwordHash: Value(userJson['passwordHash'] as String? ?? ''),
            avatarUrl: Value(userJson['avatarUrl'] as String?),
            createdAt: Value(
              DateTime.tryParse(userJson['createdAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(
              DateTime.tryParse(userJson['updatedAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      final rawProjects =
          (backup['projects'] as List<dynamic>? ?? const <dynamic>[]);
      for (final raw in rawProjects) {
        final map = raw as Map<String, dynamic>;
        await into(projects).insertOnConflictUpdate(
          ProjectsCompanion(
            id: Value(map['id'] as String),
            ownerId: Value(userId),
            name: Value(map['name'] as String? ?? ''),
            description: Value(map['description'] as String? ?? ''),
            startDate: Value(
              DateTime.tryParse(map['startDate'] as String? ?? '') ??
                  DateTime.now(),
            ),
            endDate: Value(
              map['endDate'] == null
                  ? null
                  : DateTime.tryParse(map['endDate'] as String),
            ),
            budget: Value((map['budget'] as num?)?.toDouble() ?? 0),
            spent: Value((map['spent'] as num?)?.toDouble() ?? 0),
            status: Value(map['status'] as String? ?? 'Planning'),
            category: Value(map['category'] as String? ?? 'General'),
            progress: Value((map['progress'] as num?)?.toDouble() ?? 0),
            imageUrl: Value(map['imageUrl'] as String?),
            createdAt: Value(
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      final rawExpenses =
          (backup['expenses'] as List<dynamic>? ?? const <dynamic>[]);
      for (final raw in rawExpenses) {
        final map = raw as Map<String, dynamic>;
        await into(expenses).insertOnConflictUpdate(
          ExpensesCompanion(
            id: Value(map['id'] as String),
            projectId: Value(map['projectId'] as String),
            merchant: Value(map['merchant'] as String? ?? ''),
            amount: Value((map['amount'] as num?)?.toDouble() ?? 0),
            date: Value(
              DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
            ),
            category: Value(map['category'] as String? ?? 'Other'),
            notes: Value(map['notes'] as String?),
            receiptImage: Value(map['receiptImage'] as String?),
            status: Value(map['status'] as String? ?? 'Logged'),
            quantityOriginal: Value((map['quantityOriginal'] as num?)?.toDouble()),
            unitOriginal: Value(map['unitOriginal'] as String?),
            quantityBase: Value((map['quantityBase'] as num?)?.toDouble()),
            unitBase: Value(map['unitBase'] as String?),
            createdAt: Value(
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      final rawTasks = (backup['tasks'] as List<dynamic>? ?? const <dynamic>[]);
      for (final raw in rawTasks) {
        final map = raw as Map<String, dynamic>;
        await into(tasks).insertOnConflictUpdate(
          TasksCompanion(
            id: Value(map['id'] as String),
            projectId: Value(map['projectId'] as String),
            title: Value(map['title'] as String? ?? ''),
            description: Value(map['description'] as String?),
            status: Value(map['status'] as String? ?? 'pending'),
            priority: Value(map['priority'] as String? ?? 'Medium'),
            dueDate: Value(
              map['dueDate'] == null
                  ? null
                  : DateTime.tryParse(map['dueDate'] as String),
            ),
            assignedTo: Value(map['assignedTo'] as String?),
            createdAt: Value(
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      final rawReceipts =
          (backup['receipts'] as List<dynamic>? ?? const <dynamic>[]);
      for (final raw in rawReceipts) {
        final map = raw as Map<String, dynamic>;
        await into(receipts).insertOnConflictUpdate(
          ReceiptsCompanion(
            id: Value(map['id'] as String),
            expenseId: Value(map['expenseId'] as String),
            imageUrl: Value(map['imageUrl'] as String? ?? ''),
            ocrData: Value(map['ocrData'] as String?),
            confidence: Value((map['confidence'] as num?)?.toDouble()),
            processedAt: Value(
              map['processedAt'] == null
                  ? null
                  : DateTime.tryParse(map['processedAt'] as String),
            ),
            createdAt: Value(
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      final rawTags =
          (backup['projectTags'] as List<dynamic>? ?? const <dynamic>[]);
      for (final raw in rawTags) {
        final map = raw as Map<String, dynamic>;
        await into(projectTags).insertOnConflictUpdate(
          ProjectTagsCompanion(
            projectId: Value(map['projectId'] as String),
            tag: Value(map['tag'] as String? ?? ''),
          ),
        );
      }

      final rawActivities =
          (backup['activityLogs'] as List<dynamic>? ?? const <dynamic>[]);
      for (final raw in rawActivities) {
        final map = raw as Map<String, dynamic>;
        await into(activityLogs).insertOnConflictUpdate(
          ActivityLogsCompanion(
            id: Value(map['id'] as String),
            projectId: Value(map['projectId'] as String),
            title: Value(map['title'] as String? ?? ''),
            description: Value(map['description'] as String?),
            activityType: Value(map['activityType'] as String? ?? 'other'),
            occurredAt: Value(
              DateTime.tryParse(map['occurredAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
            hoursSpent: Value((map['hoursSpent'] as num?)?.toDouble()),
            performedBy: Value(map['performedBy'] as String?),
            location: Value(map['location'] as String?),
            linkedExpenseId: Value(map['linkedExpenseId'] as String?),
            createdAt: Value(
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      final rawMilestones =
          (backup['milestones'] as List<dynamic>? ?? const <dynamic>[]);
      for (final raw in rawMilestones) {
        final map = raw as Map<String, dynamic>;
        await into(projectMilestones).insertOnConflictUpdate(
          ProjectMilestonesCompanion(
            id: Value(map['id'] as String),
            projectId: Value(map['projectId'] as String),
            title: Value(map['title'] as String? ?? ''),
            description: Value(map['description'] as String?),
            dueDate: Value(
              map['dueDate'] == null
                  ? null
                  : DateTime.tryParse(map['dueDate'] as String),
            ),
            status: Value(map['status'] as String? ?? 'pending'),
            sortOrder: Value((map['sortOrder'] as num?)?.toInt() ?? 0),
            completedAt: Value(
              map['completedAt'] == null
                  ? null
                  : DateTime.tryParse(map['completedAt'] as String),
            ),
            createdAt: Value(
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      final importedProjects = await (select(
        projects,
      )..where((t) => t.ownerId.equals(userId))).get();
      for (final project in importedProjects) {
        await _updateProjectSpentAndProgress(project.id);
      }
    });
  }

  // ===== SETTINGS QUERIES =====

  Future<String?> getSetting(String key) {
    return (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull()
        .then((value) => value?.value);
  }

  Future<int> insertOrUpdateSetting(String key, String value) async {
    final existing = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();

    if (existing != null) {
      // Update existing
      return (update(settings)..where((t) => t.key.equals(key))).write(
        SettingsCompanion(
          value: Value(value),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      // Insert new
      return into(settings).insert(
        SettingsCompanion.insert(
          key: key,
          value: value,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'projectrack.sqlite'));
    return NativeDatabase(file);
  });
}
