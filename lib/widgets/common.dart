import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';

export '../core/widgets/app_widgets.dart';

String pretty(String? s) {
  if (s == null || s.isEmpty) return '-';
  final t = s.replaceAll('_', ' ');
  return t[0].toUpperCase() + t.substring(1);
}

String fmtDate(dynamic iso, {bool time = false}) {
  if (iso == null) return '-';
  final d = DateTime.tryParse(iso.toString())?.toLocal();
  if (d == null) return iso.toString();
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${two(d.day)}/${two(d.month)}/${d.year}';
  return time ? '$date ${two(d.hour)}:${two(d.minute)}' : date;
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Color statusColor(String s) {
  switch (s) {
    case 'submitted':
      return AppColors.statusSubmitted;
    case 'verified':
      return AppColors.statusVerified;
    case 'in_progress':
      return AppColors.statusInProgress;
    case 'under_review':
      return AppColors.statusUnderReview;
    case 'visit_scheduled':
      return AppColors.statusVisitScheduled;
    case 'resolved':
      return AppColors.statusResolved;
    case 'rejected':
      return AppColors.statusRejected;
    default:
      return AppColors.textTertiary;
  }
}

Color riskColor(String r) {
  switch (r) {
    case 'low':
      return AppColors.riskLow;
    case 'medium':
      return AppColors.riskMedium;
    case 'high':
      return AppColors.riskHigh;
    case 'critical':
      return AppColors.riskCritical;
    default:
      return AppColors.riskUnassigned;
  }
}

/// Small colored, outlined label — used for status/risk/role badges.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

class StatusPill extends Pill {
  StatusPill(String status, {super.key}) : super(pretty(status), statusColor(status));
}

class RiskPill extends Pill {
  RiskPill(String risk, {super.key}) : super('Risk: ${pretty(risk)}', riskColor(risk));
}

/// Simple "loading / error / retry" wrapper used by list screens.
class AsyncBody<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  const AsyncBody({super.key, required this.future, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const LoadingWidget();
      }
      if (snap.hasError) {
        return ErrorStateWidget(message: '${snap.error}', onRetry: onRetry);
      }
      return builder(snap.data as T);
    },
  );
}

/// Centers content and limits its width so dashboards look good on wide web screens.
class PageWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PageWidth({super.key, required this.child, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
  );
}
