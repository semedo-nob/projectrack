// lib/constants/models/project_model.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../themes/app_colors.dart';
import '../../database/database.dart' as db;

// ===== DRIFT COMPANION CLASS FOR DATABASE OPERATIONS =====
/// This class is used for database operations with Drift
class ProjectCompanion extends drift.Insertable<Project> {
  final drift.Value<String> id;
  final drift.Value<String> name;
  final drift.Value<String> description;
  final drift.Value<DateTime> startDate;
  final drift.Value<DateTime?> endDate;
  final drift.Value<double> budget;
  final drift.Value<double> spent;
  final drift.Value<String> status;
  final drift.Value<String> category;
  final drift.Value<double> progress;
  final drift.Value<String> imageUrl;
  final drift.Value<DateTime> createdAt;
  final drift.Value<DateTime> updatedAt;

  ProjectCompanion({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    this.endDate = const drift.Value.absent(),
    required this.budget,
    this.spent = const drift.Value(0.0),
    required this.status,
    required this.category,
    this.progress = const drift.Value(0.0),
    this.imageUrl = const drift.Value(''),
    required this.createdAt,
    required this.updatedAt,
  });

  // In lib/constants/models/project_model.dart, replace the toColumns method:

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};

    void addIfPresent(String key, drift.Value value) {
      if (value.present || !nullToAbsent) {
        map[key] = drift.Variable(value.value);
      }
    }

    addIfPresent('id', id);
    addIfPresent('name', name);
    addIfPresent('description', description);
    addIfPresent('start_date', startDate);
    addIfPresent('end_date', endDate);
    addIfPresent('budget', budget);
    addIfPresent('spent', spent);
    addIfPresent('status', status);
    addIfPresent('category', category);
    addIfPresent('progress', progress);
    addIfPresent('image_url', imageUrl);
    addIfPresent('created_at', createdAt);
    addIfPresent('updated_at', updatedAt);

    return map;
  }

  // Factory constructor for creating a new project
  factory ProjectCompanion.insert({
    required String id,
    required String name,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
    required double budget,
    double spent = 0.0,
    required String status,
    required String category,
    double progress = 0.0,
    String imageUrl = '',
  }) {
    final now = DateTime.now();
    return ProjectCompanion(
      id: drift.Value(id),
      name: drift.Value(name),
      description: drift.Value(description),
      startDate: drift.Value(startDate),
      endDate: drift.Value(endDate),
      budget: drift.Value(budget),
      spent: drift.Value(spent),
      status: drift.Value(status),
      category: drift.Value(category),
      progress: drift.Value(progress),
      imageUrl: drift.Value(imageUrl),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );
  }
}

// ===== MAIN PROJECT MODEL =====
class Project {
  final String id;
  /// Local account that owns this project (null for legacy/mock rows).
  final String? ownerId;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final double budget;
  final double spent;
  final String status;
  final String category;
  final List<String> tags;
  final double progress;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    this.ownerId,
    required this.name,
    required this.description,
    required this.startDate,
    this.endDate,
    required this.budget,
    required this.spent,
    required this.status,
    required this.category,
    required this.tags,
    required this.progress,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculated getters
  double get remainingBudget => budget - spent;

  // Status color mapping for UI
  Color getStatusColor() {
    switch (status) {
      case 'Active':
        return AppColors.primary;
      case 'Planning':
        return AppColors.info;
      case 'On Hold':
        return AppColors.warning;
      case 'Done':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  // Convert to JSON for API calls or sharing
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (ownerId != null) 'ownerId': ownerId,
      'name': name,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'budget': budget,
      'spent': spent,
      'remaining': remainingBudget,
      'status': status,
      'category': category,
      'tags': tags,
      'progress': progress,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      ownerId: json['ownerId'] as String?,
      name: json['name'],
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      budget: json['budget'].toDouble(),
      spent: json['spent'].toDouble(),
      status: json['status'],
      category: json['category'],
      tags: List<String>.from(json['tags'] ?? []),
      progress: json['progress'].toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Create from Drift database row
  factory Project.fromDrift(db.Project data) {
    return Project(
      id: data.id,
      ownerId: data.ownerId,
      name: data.name,
      description: data.description,
      startDate: data.startDate,
      endDate: data.endDate,
      budget: data.budget,
      spent: data.spent,
      status: data.status,
      category: data.category,
      tags: [], // Tags might be stored in a separate table or as JSON
      progress: data.progress,
      imageUrl: data.imageUrl ?? '',
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  // Create a copy with updated fields
  Project copyWith({
    String? ownerId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    double? spent,
    String? status,
    String? category,
    List<String>? tags,
    double? progress,
    String? imageUrl,
  }) {
    return Project(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
      status: status ?? this.status,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      progress: progress ?? this.progress,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Mock data generator for UI testing
  static List<Project> getMockProjects() {
    final now = DateTime.now();
    return [
      Project(
        id: '1',
        name: 'Website Redesign',
        description: 'Complete overhaul of company website with modern UI/UX',
        startDate: DateTime(2024, 1, 15),
        endDate: DateTime(2024, 4, 30),
        budget: 20000,
        spent: 12000,
        status: 'Active',
        category: 'Development',
        tags: ['web', 'design', 'frontend'],
        progress: 0.75,
        imageUrl: 'https://images.unsplash.com/photo-1581291518633-83b4ebd1d83e',
        createdAt: now,
        updatedAt: now,
      ),
      Project(
        id: '2',
        name: 'Q4 Marketing Campaign',
        description: 'End of year marketing campaign for product launch',
        startDate: DateTime(2024, 9, 1),
        endDate: null,
        budget: 15000,
        spent: 4500,
        status: 'Planning',
        category: 'Marketing',
        tags: ['marketing', 'social-media', 'ads'],
        progress: 0.30,
        imageUrl: 'https://images.unsplash.com/photo-1557838923-2985c318be48',
        createdAt: now,
        updatedAt: now,
      ),
      Project(
        id: '3',
        name: 'Office Renovation',
        description: 'Renovation of main office space and meeting rooms',
        startDate: DateTime(2024, 3, 1),
        endDate: DateTime(2024, 8, 15),
        budget: 50000,
        spent: 50000,
        status: 'Done',
        category: 'Construction',
        tags: ['construction', 'interior', 'furniture'],
        progress: 1.0,
        imageUrl: 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d',
        createdAt: now,
        updatedAt: now,
      ),
      Project(
        id: '4',
        name: 'Mobile App Development',
        description: 'Cross-platform mobile app for customer engagement',
        startDate: DateTime(2024, 2, 1),
        endDate: DateTime(2024, 6, 30),
        budget: 35000,
        spent: 21000,
        status: 'Active',
        category: 'Development',
        tags: ['mobile', 'ios', 'android', 'flutter'],
        progress: 0.60,
        imageUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c',
        createdAt: now,
        updatedAt: now,
      ),
      Project(
        id: '5',
        name: 'Annual Conference',
        description: 'Company annual conference and networking event',
        startDate: DateTime(2024, 10, 10),
        endDate: null,
        budget: 25000,
        spent: 8000,
        status: 'Planning',
        category: 'Events',
        tags: ['event', 'conference', 'networking'],
        progress: 0.25,
        imageUrl: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

