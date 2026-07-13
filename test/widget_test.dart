import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectrack1/themes/app_colors.dart';

void main() {
  test('AppColors Modern Industrial Violet brand color validation', () {
    expect(AppColors.primary, const Color(0xFF5E4EE3));
    expect(AppColors.primaryLight, const Color(0xFF7B6EF6));
    expect(AppColors.primaryDark, const Color(0xFF4338B5));
    expect(AppColors.accent, const Color(0xFF8B7CF6));
    expect(AppColors.success, const Color(0xFF2F855A));
    expect(AppColors.warning, const Color(0xFFD69E2E));
    expect(AppColors.error, const Color(0xFFC53030));
    expect(AppColors.info, const Color(0xFF2B6CB0));
  });
}
