import 'package:flutter/material.dart';

/// Centralized color palette for the Shomman app.
///
/// Red is the primary brand color. Everything else is a natural,
/// professional, neutral supporting palette. Screens should reference
/// [AppColors] rather than hardcoding colors, so the whole app stays
/// visually consistent and easy to re-theme later.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------- Brand
  static const Color primary = Color(0xFFC62828); // Professional red
  static const Color primaryDark = Color(0xFF7A1D1D); // Dark red / burgundy
  static const Color primaryLight = Color(0xFFE57373);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ------------------------------------------------------------- Surfaces
  static const Color background = Color(0xFFF7F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F2F4);
  static const Color surfaceDark = Color(0xFF1C1B1F);

  // ----------------------------------------------------------------- Text
  static const Color textPrimary = Color(0xFF1C1B1F);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ------------------------------------------------------------- Borders
  static const Color border = Color(0xFFE2E3E6);
  static const Color divider = Color(0xFFE9EAEC);

  // ------------------------------------------------------------- Status
  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFB45309);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorBg = Color(0xFFFDECEA);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFE8F0FE);

  // ------------------------------------------------ Complaint status colors
  static const Color statusSubmitted = Color(0xFF6B7280);
  static const Color statusUnderReview = Color(0xFF4F46E5);
  static const Color statusVerified = Color(0xFF2563EB);
  static const Color statusInProgress = Color(0xFF7C3AED);
  static const Color statusVisitScheduled = Color(0xFFB45309);
  static const Color statusResolved = Color(0xFF2E7D32);
  static const Color statusRejected = Color(0xFFD32F2F);

  // ---------------------------------------------------------- Risk levels
  static const Color riskUnassigned = Color(0xFF9CA3AF);
  static const Color riskLow = Color(0xFF2E7D32);
  static const Color riskMedium = Color(0xFFB45309);
  static const Color riskHigh = Color(0xFFEA580C);
  static const Color riskCritical = Color(0xFF991B1B);
}
