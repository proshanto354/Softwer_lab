import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable, professional building blocks shared across the app.
/// Keeping them here avoids repeating the same look-and-feel logic on
/// every screen and keeps the visual language consistent.

// -------------------------------------------------------------------------
// Buttons
// -------------------------------------------------------------------------

/// A full-width primary action button with a built-in loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
    )
        : icon == null
        ? Text(label)
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Text(label),
    ]);

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
      child: child,
    );
  }
}

/// A full-width secondary (outlined) action button.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final style = color == null
        ? null
        : OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color!.withValues(alpha: 0.5)));
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return OutlinedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 20), label: Text(label));
  }
}

// -------------------------------------------------------------------------
// Text field
// -------------------------------------------------------------------------

/// A consistent text field used across forms (auth, profile, elder details,
/// complaint form, etc). Wraps [TextField] so screens keep using their own
/// [TextEditingController]s and validation logic unchanged.
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    maxLines: obscureText ? 1 : maxLines,
    onSubmitted: onSubmitted,
    onChanged: onChanged,
    enabled: enabled,
    autofocus: autofocus,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: maxLines > 1,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
    ),
  );
}

// -------------------------------------------------------------------------
// Section header
// -------------------------------------------------------------------------

/// A small uppercase-ish heading used to introduce a group of content
/// (e.g. "Quick access", "Recent activity").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: 10, top: 4),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ]),
  );
}

// -------------------------------------------------------------------------
// Feature card (used for the home screen's grid of features)
// -------------------------------------------------------------------------

class FeatureCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;
  final int? badgeCount;

  const FeatureCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accent,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (badgeCount != null && badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ]),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Loading / empty / error states
// -------------------------------------------------------------------------

class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(),
      if (message != null) ...[
        const SizedBox(height: 12),
        Text(message!, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ]),
  );
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ]),
    ),
  );
}

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorStateWidget({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
          child: const Icon(Icons.error_outline, size: 36, color: AppColors.error),
        ),
        const SizedBox(height: 16),
        const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]),
    ),
  );
}

// -------------------------------------------------------------------------
// Profile header (used on Home / dashboards)
// -------------------------------------------------------------------------

class ProfileHeader extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String? subtitle;

  const ProfileHeader({super.key, required this.name, required this.roleLabel, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Row(children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(initial, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello, $name', style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle ?? roleLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ),
    ]);
  }
}

// -------------------------------------------------------------------------
// Custom app bar (used where a screen wants the standard look explicitly,
// e.g. auth screens without a Scaffold app bar)
// -------------------------------------------------------------------------

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const CustomAppBar({super.key, required this.title, this.actions, this.leading, this.centerTitle = false});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title),
    actions: actions,
    leading: leading,
    centerTitle: centerTitle,
  );
}
