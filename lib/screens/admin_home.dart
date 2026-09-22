import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'admin_reports_tab.dart';
import 'admin_users_tab.dart';
import 'complaint_detail_screen.dart';

const _allStatuses = ['submitted', 'under_review', 'verified', 'in_progress', 'visit_scheduled', 'resolved', 'rejected'];

class _NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  _NavItem(this.label, this.icon, this.page);
}

/// Dashboard for officers and administrators. Uses a side navigation rail on wide screens (web)
/// and a bottom bar on phones.
class AdminHome extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminHome({super.key, required this.user});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin';
    final wide = MediaQuery.of(context).size.width >= 900;
    final items = <_NavItem>[
      _NavItem('Cases', Icons.folder_open_outlined, CasesTab(wide: wide)),
      _NavItem('SOS', Icons.sos, const SosTab()),
      _NavItem('Analytics', Icons.bar_chart_outlined, const AnalyticsTab()),
      _NavItem('Reports', Icons.description_outlined, const ReportsTab()),
      if (isAdmin) _NavItem('Users', Icons.people_outline, const UsersTab()),
    ];
    if (_index >= items.length) _index = 0;
    final body = IndexedStack(index: _index, children: items.map((e) => e.page).toList());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shomman • Welfare dashboard'),
        actions: [
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Row(children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      ('${widget.user['name'] ?? '?'}').trim().isEmpty
                          ? '?'
                          : '${widget.user['name']}'.trim()[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${widget.user['name']}  •  ${pretty(widget.user['role'])}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wide
          ? Row(children: [
        NavigationRail(
          selectedIndex: _index,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final e in items)
              NavigationRailDestination(icon: Icon(e.icon), label: Text(e.label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final e in items) NavigationDestination(icon: Icon(e.icon), label: e.label),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Cases
class CasesTab extends StatefulWidget {
  final bool wide;
  const CasesTab({super.key, required this.wide});
  @override
  State<CasesTab> createState() => _CasesTabState();
}

class _CasesTabState extends State<CasesTab> {
  late Future<List<dynamic>> _future;
  String? _status;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async =>
      await Api.get('/admin/complaints${_status == null ? '' : '?status=$_status'}') as List<dynamic>;

  void _reload() => setState(() => _future = _load());

  Widget _filters() => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: const Text('All'),
            selected: _status == null,
            onSelected: (_) {
              _status = null;
              _reload();
            },
          ),
        ),
        for (final s in _allStatuses)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(pretty(s)),
              selected: _status == s,
              onSelected: (_) {
                _status = s;
                _reload();
              },
            ),
          ),
      ]),
    ),
  );

  Widget _list() => AsyncBody<List<dynamic>>(
    future: _future,
    onRetry: _reload,
    builder: (list) {
      if (list.isEmpty) {
        return const EmptyStateWidget(
          icon: Icons.folder_open_outlined,
          title: 'No cases found',
          subtitle: 'Try a different filter, or check back later.',
        );
      }
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = list[i];
            final id = c['id'] as int;
            return Container(
              color: widget.wide && _selected == id ? AppColors.primary.withValues(alpha: 0.06) : null,
              child: ListTile(
                title: Text('#$id • ${c['elder_name']} — ${pretty(c['category'])}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusPill(c['status']),
                    RiskPill(c['risk_level']),
                    Text('${c['elder_district'] ?? ''} ${fmtDate(c['created_at'])}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                onTap: () async {
                  if (widget.wide) {
                    setState(() => _selected = id);
                  } else {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ComplaintDetailScreen(id: id, staff: true),
                    ));
                    _reload();
                  }
                },
              ),
            );
          },
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final list = Column(children: [_filters(), Expanded(child: _list())]);
    if (!widget.wide) return list;
    return Row(children: [
      SizedBox(width: 440, child: list),
      const VerticalDivider(width: 1),
      Expanded(
        child: _selected == null
            ? const EmptyStateWidget(icon: Icons.touch_app_outlined, title: 'Select a case to see its details')
            : ComplaintDetailScreen(
          key: ValueKey(_selected),
          id: _selected!,
          staff: true,
          onChanged: _reload,
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- SOS
class SosTab extends StatefulWidget {
  const SosTab({super.key});
  @override
  State<SosTab> createState() => _SosTabState();
}

class _SosTabState extends State<SosTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async => await Api.get('/admin/sos') as List<dynamic>;
  void _reload() => setState(() => _future = _load());

  Future<void> _set(int id, String status) async {
    try {
      await Api.patch('/admin/sos/$id', {'status': status});
      _reload();
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    child: AsyncBody<List<dynamic>>(
      future: _future,
      onRetry: _reload,
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(icon: Icons.sos, title: 'No SOS requests', subtitle: 'All clear for now.');
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final s = list[i];
              final open = s['status'] == 'open';
              return Card(
                color: open ? AppColors.errorBg : AppColors.surface,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.sos, color: open ? AppColors.error : AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${s['elder_name'] ?? 'Unknown elder'}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Pill(pretty(s['status']), open ? AppColors.error : AppColors.textSecondary),
                    ]),
                    const SizedBox(height: 8),
                    if (s['message'] != null) Text(s['message']),
                    Text('From: ${s['user_name']} ${s['user_phone'] ?? ''}'),
                    if (s['elder_address'] != null)
                      Text('Address: ${s['elder_address']}, ${s['elder_district'] ?? ''}'),
                    Text(fmtDate(s['created_at'], time: true), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Row(children: [
                      if (open)
                        FilledButton.tonal(
                          onPressed: () => _set(s['id'] as int, 'acknowledged'),
                          child: const Text('Acknowledge'),
                        ),
                      if (s['status'] != 'closed') ...[
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: () => _set(s['id'] as int, 'closed'), child: const Text('Close')),
                      ],
                    ]),
                  ]),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- Analytics
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(await Api.get('/admin/analytics'));
  void _reload() => setState(() => _future = _load());

  Widget _stat(String label, Object? value, IconData icon) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text('${value ?? '-'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    ),
  );

  Widget _bars(String title, List<dynamic> rows) {
    final maxCount = rows.fold<num>(1, (m, r) => (r['count'] as num) > m ? r['count'] as num : m);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (rows.isEmpty) const Text('No data yet', style: TextStyle(color: AppColors.textSecondary)),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 120, child: Text(pretty('${r['label']}'), overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (r['count'] as num) / maxCount,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
                SizedBox(width: 34, child: Text('${r['count']}', textAlign: TextAlign.end)),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    child: AsyncBody<Map<String, dynamic>>(
      future: _future,
      onRetry: _reload,
      builder: (d) => RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            _stat('Total cases', d['total'], Icons.folder_outlined),
            const SizedBox(width: 8),
            _stat('Active', d['active'], Icons.pending_actions_outlined),
            const SizedBox(width: 8),
            _stat('Resolved', d['resolved'], Icons.check_circle_outline),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _stat('Open SOS', d['open_sos'], Icons.sos),
            const SizedBox(width: 8),
            _stat('Flagged checks', d['flagged_wellbeing_this_month'], Icons.flag_outlined),
            const SizedBox(width: 8),
            _stat('Avg. days to resolve', d['avg_resolution_days'], Icons.timer_outlined),
          ]),
          const SizedBox(height: 14),
          _bars('By status', d['by_status']),
          _bars('By risk level', d['by_risk']),
          _bars('By category', d['by_category']),
          _bars('By district', d['by_district']),
          _bars('Cases per month (last 6 months)', d['monthly']),
        ]),
      ),
    ),
  );
}
