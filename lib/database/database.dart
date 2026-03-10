// lib/database/database.dart
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
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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

// ===== DATABASE CLASS =====

@DriftDatabase(
  tables: [
    Projects,
    Expenses,
    Tasks,
    Receipts,
    Categories,
    Settings,
    Users,
    ProjectTags,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
      },
    );
  }

  // ===== PROJECT QUERIES =====

  Future<List<Project>> getAllProjects() => select(projects).get();

  Stream<List<Project>> watchAllProjects() => select(projects).watch();

  Future<Project?> getProject(String id) {
    return (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();
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

  Future<List<Project>> searchProjects(String query) {
    return (select(projects)
      ..where((t) =>
      t.name.contains(query) |
      t.description.contains(query) |
      t.category.contains(query))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  // ===== EXPENSE QUERIES =====

  Future<List<Expense>> getExpensesByProject(String projectId) {
    return (select(expenses)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<Expense>> watchExpensesByProject(String projectId) {
    return (select(expenses)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
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
      final result = await (delete(expenses)..where((t) => t.id.equals(id))).go();
      await _updateProjectSpentAndProgress(projectId);
      return result;
    });
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
    final list = await (select(expenses)
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
      ..orderBy([(t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)]))
        .get();
  }

  Stream<List<Task>> watchTasksByProject(String projectId) {
    return (select(tasks)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<Task?> getTask(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);

  Future<bool> updateTask(TasksCompanion task) => update(tasks).replace(task);

  Future<int> deleteTask(String id) => (delete(tasks)..where((t) => t.id.equals(id))).go();

  // ===== DASHBOARD STATS =====

  Future<Map<String, dynamic>> getDashboardStats() async {
    final projectCount = await (select(projects).map((p) => p.id).get()).then((ids) => ids.length);

    final totalBudget = await (select(projects).map((p) => p.budget).get())
        .then((budgets) => budgets.fold(0.0, (a, b) => a + b));

    final totalSpent = await (select(projects).map((p) => p.spent).get())
        .then((spent) => spent.fold(0.0, (a, b) => a + b));

    final pendingTasks = await (select(tasks)
      ..where((t) => t.status.equals('Done').not()))
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

  // ===== USER QUERIES =====

  Future<User?> getUser(String id) {
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<User?> getUserByEmail(String email) {
    return (select(users)..where((t) => t.email.equals(email))).getSingleOrNull();
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

  // ===== SETTINGS QUERIES =====

  Future<String?> getSetting(String key) {
    return (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull()
        .then((value) => value?.value);
  }

  Future<int> insertOrUpdateSetting(String key, String value) async {
    final existing = await (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();

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