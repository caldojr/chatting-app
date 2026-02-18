import 'package:flutter/material.dart';
import 'package:g11chat_app/theme/app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryDarkBlue,
  );

  static const TextStyle screenSubtitle = TextStyle(
    fontSize: 15,
    color: AppColors.accentText,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryDarkBlue,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.accentText,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle navLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryDarkBlue,
  );

  static const TextStyle listTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryDarkBlue,
  );

  static const TextStyle listSubtitle = TextStyle(
    fontSize: 14,
    color: AppColors.accentText,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.primaryDarkBlue,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: Color(0xFF50545C),
  );
}
