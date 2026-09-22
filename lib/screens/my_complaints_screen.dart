import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'complaint_detail_screen.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});
  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async => await Api.get('/complaints/mine') as List<dynamic>;
  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('My complaints')),
    body: AsyncBody<List<dynamic>>(
      future: _future,
      onRetry: _reload,
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.track_changes_outlined,
            title: 'No complaints yet',
            subtitle: 'You have not submitted any complaints.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                title: Text('#${c['id']} • ${pretty(c['category'])} — ${c['elder_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusPill(c['status']),
                    Text(fmtDate(c['created_at']), style: Theme.of(context).textTheme.bodySmall),
                    if (c['is_anonymous'] == 1 || c['is_anonymous'] == true)
                      const Icon(Icons.visibility_off_outlined, size: 14, color: AppColors.textTertiary),
                  ]),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ComplaintDetailScreen(id: c['id'] as int, staff: false)),
                  );
                  _reload();
                },
              );
            },
          ),
        );
      },
    ),
  );
}
