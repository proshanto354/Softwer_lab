import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'complaint_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    try {
      await Api.post('/notifications/sync', {});
    } catch (_) {}
    return await Api.get('/notifications') as List<dynamic>;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _markAll() async {
    try {
      await Api.patch('/notifications/read-all', {});
      _reload();
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    try {
      if (n['is_read'] != true) await Api.patch('/notifications/${n['id']}/read', {});
    } catch (_) {}
    if (!mounted) return;
    final cid = n['complaint_id'];
    if (cid is int) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ComplaintDetailScreen(id: cid, staff: false)),
      );
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(tooltip: 'Mark all as read', onPressed: _markAll, icon: const Icon(Icons.done_all)),
      ],
    ),
    body: AsyncBody<List<dynamic>>(
      future: _future,
      onRetry: _reload,
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.notifications_none,
            title: 'No notifications yet',
            subtitle: 'You will see updates on your complaints here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = Map<String, dynamic>.from(list[i] as Map);
              final unread = n['is_read'] != true;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: unread ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceAlt,
                  child: Icon(unread ? Icons.notifications_active_outlined : Icons.notifications_none,
                      color: unread ? AppColors.primary : AppColors.textTertiary, size: 20),
                ),
                title: Text('${n['title']}',
                    style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                subtitle: Text('${n['body']}\n${fmtDate(n['created_at'], time: true)}'),
                isThreeLine: true,
                onTap: () => _open(n),
              );
            },
          ),
        );
      },
    ),
  );
}
