// lib/widgets/project_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/providers/currency_provider.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final bool isSelected;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isListView;

  const ProjectCard({
    super.key,
    required this.project,
    required this.isSelected,
    required this.isDark,
    this.onTap,
    this.onLongPress,
    this.isListView = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: isListView
                ? _buildListViewContent(context)
                : _buildGridViewContent(context),
          ),
          if (isSelected) _buildSelectionIndicator(),
        ],
      ),
    );
  }

  // GRID VIEW LAYOUT — grid cells have fixed height (aspect ratio); scale body to fit.
  Widget _buildGridViewContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImage(height: 92),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  clipBehavior: Clip.hardEdge,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                project.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 80),
                              child: _buildStatusBadge(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _buildBudget(context),
                        const SizedBox(height: 6),
                        _buildProgressBar(),
                        if (project.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildTags(),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // LIST VIEW LAYOUT - Fixed overflow issues
  Widget _buildListViewContent(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image with fixed width
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 90,
              height: double.infinity,
              child: _buildImage(height: double.infinity, width: 90),
            ),
          ),

          // Content - uses flexible width
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and Status Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 70),
                        child: _buildStatusBadge(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Category and Budget Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          project.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildBudget(context),
                    ],
                  ),

                  // Description - optional, limited to 1 line in list view
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      project.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Progress Bar
                  _buildProgressBar(),

                  // Tags - optional
                  if (project.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildTags(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage({required double height, double? width}) {
    return SizedBox(
      height: height,
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isListView ? 0 : 16),
        child: Container(
          color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
          child: project.imageUrl.isNotEmpty
              ? Image.network(
            project.imageUrl,
            fit: BoxFit.cover,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade400,
                  size: 30,
                ),
              );
            },
          )
              : Center(
            child: Icon(
              Icons.folder_rounded,
              size: 30,
              color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusColor = project.getStatusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 45),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        project.status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBudget(BuildContext context) {
    final currency = Provider.of<CurrencyProvider>(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_money_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
        const SizedBox(width: 2),
        Text(
          currency.format(project.budget),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progressValue = project.progress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            Text(
              '${(progressValue * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progressValue,
            backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              project.status == 'Done' ? AppColors.success : AppColors.primary,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: project.tags.take(2).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.primarySubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectionIndicator() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.darkBackground : Colors.white,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 12,
          color: Colors.black,
        ),
      ),
    );
  }
}