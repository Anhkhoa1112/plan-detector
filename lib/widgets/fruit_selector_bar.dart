import 'package:flutter/material.dart';

import '../models/fruit_analysis.dart';
import '../theme/app_colors.dart';

class FruitSelectorBar extends StatelessWidget {
  const FruitSelectorBar({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.isDarkMode,
  });

  final FruitCategory selectedCategory;
  final ValueChanged<FruitCategory> onCategoryChanged;
  final bool isDarkMode;

  static const List<FruitCategory> categories = [
    FruitCategory.auto,
    FruitCategory.banana,
    FruitCategory.mango,
    FruitCategory.papaya,
    FruitCategory.orange,
    FruitCategory.lemon,
    FruitCategory.apple,
    FruitCategory.tomato,
    FruitCategory.avocado,
    FruitCategory.watermelon,
    FruitCategory.dragonFruit,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selectedCategory;

          return _buildFruitChip(context, cat, isSelected);
        },
      ),
    );
  }

  Widget _buildFruitChip(BuildContext context, FruitCategory cat, bool isSelected) {
    final activeBg = isDarkMode
        ? AppColors.primaryEmerald.withValues(alpha: 0.22)
        : AppColors.primaryEmerald.withValues(alpha: 0.16);
    final inactiveBg = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final activeBorder = AppColors.primaryEmerald;
    final inactiveBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    final activeTextColor = isDarkMode ? AppColors.primaryEmerald : const Color(0xFF0D7847);
    final inactiveTextColor = isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onCategoryChanged(cat),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeBorder : inactiveBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cat.iconEmoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                cat.nameVi,
                style: TextStyle(
                  color: isSelected ? activeTextColor : inactiveTextColor,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
