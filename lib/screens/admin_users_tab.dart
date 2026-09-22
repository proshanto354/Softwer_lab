import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

const allRoles = ['elder', 'family', 'neighbor', 'social_worker', 'volunteer', 'officer', 'admin'];

/// User management (administrators only): list users, change roles, enable/disable accounts.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  late Future<List<dynamic>> _future;
  final _search = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() async => await Api.get('/admin/users') as List<dynamic>;
  void _reload() => setState(() => _future = _load());

  Future<void> _edit(Map<String, dynamic> u) async {
    if (u['id'] == FirebaseAuth.instance.currentUser?.uid) {
      snack(context, 'You cannot change your own account here.');
      return;
    }
    String role = u['role'] as String;
    bool active = u['status'] != 'disabled';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('${u['name'] ?? 'User'}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['email'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: allRoles.map((r) => DropdownMenuItem(value: r, child: Text(pretty(r)))).toList(),
              onChanged: (v) => setD(() => role = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Account active'),
              subtitle: const Text('Disabled users cannot use the app.'),
              value: active,
              onChanged: (v) => setD(() => active = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await Api.patch('/admin/users', {
        'uid': u['id'],
        'role': role,
        'status': active ? 'active' : 'disabled',
      });
      if (mounted) snack(context, 'User updated');
      _reload();
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
  }

  bool _matches(Map u) {
    if (_q.isEmpty) return true;
    final hay = '${u['name']} ${u['email']} ${u['phone']} ${u['role']}'.toLowerCase();
    return hay.contains(_q);
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: CustomTextField(
          controller: _search,
          label: 'Search',
          hint: 'Search by name, email, phone or role',
          prefixIcon: Icons.search,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        ),
      ),
      Expanded(
        child: AsyncBody<List<dynamic>>(
          future: _future,
          onRetry: _reload,
          builder: (all) {
            final list = all.where((u) => _matches(u as Map)).toList();
            if (list.isEmpty) {
              return const EmptyStateWidget(icon: Icons.people_outline, title: 'No users found');
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = Map<String, dynamic>.from(list[i] as Map);
                  final disabled = u['status'] == 'disabled';
                  final name = '${u['name'] ?? '?'}';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${u['email'] ?? '-'}  •  ${u['phone'] ?? '-'}'),
                    trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Pill(pretty(u['role']), AppColors.info),
                      if (disabled) const Pill('Disabled', AppColors.error),
                    ]),
                    onTap: () => _edit(u),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]),
  );
}
