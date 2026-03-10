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

  const ProjectCard({
    super.key,
    required this.project,
    required this.isSelected,
    required this.isDark,
    this.onTap,
    this.onLongPress,
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
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                _buildImage(),

                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      _buildStatusBadge(),

                      const SizedBox(height: 8),

                      // Title
                      _buildTitle(),

                      const SizedBox(height: 4),

                      // Category
                      _buildCategory(),

                      const SizedBox(height: 8),

                      // Budget
                      _buildBudget(context),

                      const SizedBox(height: 8),

                      // Progress Bar
                      _buildProgressBar(),

                      // Tags
                      if (project.tags.isNotEmpty) _buildTags(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selection Indicator
          if (isSelected) _buildSelectionIndicator(),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        height: 100,
        width: double.infinity,
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: project.imageUrl.isNotEmpty
            ? Image.network(
          project.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.image_not_supported_rounded,
                color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade400,
              ),
            );
          },
        )
            : Center(
          child: Icon(
            Icons.folder_rounded,
            size: 40,
            color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: project.getStatusColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        project.status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: project.getStatusColor(),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      project.name,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCategory() {
    return Text(
      project.category,
      style: TextStyle(
        fontSize: 12,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
    );
  }

  Widget _buildBudget(BuildContext context) {
    final currency = Provider.of<CurrencyProvider>(context);
    return Row(
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
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
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
              '${(project.progress * 100).toInt()}%',
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
            value: project.progress,
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
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
            ),
          );
        }).toList(),
      ),
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