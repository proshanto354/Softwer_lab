import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/download_stub.dart' if (dart.library.js_interop) '../services/download_web.dart';
import '../widgets/common.dart';

/// Report generation: summary of complaints for a period, plus CSV export.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int _days = 30; // 0 = all time
  late Future<Map<String, dynamic>> _future;

  static const _periods = {7: 'Last 7 days', 30: 'Last 30 days', 90: 'Last 90 days', 0: 'All time'};
  static const _cols = [
    'id', 'created_at', 'resolved_at', 'elder_name', 'elder_district',
    'category', 'status', 'risk_level', 'is_anonymous',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      Map<String, dynamic>.from(await Api.get('/admin/report?days=$_days'));

  void _reload() => setState(() => _future = _load());

  String _esc(dynamic v) {
    final s = v == null ? '' : '$v';
    return (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  String _csv(List<dynamic> rows) {
    final b = StringBuffer('${_cols.join(',')}\n');
    for (final r in rows) {
      b.write('${_cols.map((c) => _esc(r[c])).join(',')}\n');
    }
    return b.toString();
  }

  Future<void> _download(List<dynamic> rows) async {
    final csv = _csv(rows);
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    if (kIsWeb) {
      downloadTextFile('shomman_report_$stamp.csv', '\uFEFF$csv'); // BOM so Excel reads UTF-8
      snack(context, 'Report downloaded');
    } else {
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) snack(context, 'CSV copied to clipboard');
    }
  }

  Future<void> _copy(List<dynamic> rows) async {
    await Clipboard.setData(ClipboardData(text: _csv(rows)));
    if (mounted) snack(context, 'CSV copied to clipboard');
  }

  Map<String, int> _count(List<dynamic> rows, String key) {
    final m = <String, int>{};
    for (final r in rows) {
      final k = '${r[key] ?? 'unknown'}';
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  Widget _stat(String label, int value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    ),
  );

  Widget _bars(String title, Map<String, int> data) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxV = entries.fold<int>(1, (m, e) => e.value > m ? e.value : m);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (entries.isEmpty) const Text('No data', style: TextStyle(color: AppColors.textSecondary)),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 120, child: Text(pretty(e.key), overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: e.value / maxV,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
                SizedBox(width: 34, child: Text('${e.value}', textAlign: TextAlign.end)),
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
      builder: (d) {
        final rows = d['rows'] as List<dynamic>;
        final byStatus = _count(rows, 'status');
        final shown = rows.take(100).toList();
        return ListView(padding: const EdgeInsets.all(12), children: [
          Text('Complaint report', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text('Generated ${fmtDate(d['generated_at'], time: true)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final e in _periods.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _days == e.key,
                onSelected: (_) {
                  _days = e.key;
                  _reload();
                },
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _stat('Complaints', rows.length),
            const SizedBox(width: 8),
            _stat('Resolved', byStatus['resolved'] ?? 0),
            const SizedBox(width: 8),
            _stat('Rejected', byStatus['rejected'] ?? 0),
            const SizedBox(width: 8),
            _stat('Anonymous', rows.where((r) => r['is_anonymous'] == true).length),
          ]),
          const SizedBox(height: 14),
          _bars('By status', byStatus),
          _bars('By category', _count(rows, 'category')),
          _bars('By risk level', _count(rows, 'risk_level')),
          _bars('By district', _count(rows, 'elder_district')),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: rows.isEmpty ? null : () => _download(rows),
              icon: const Icon(Icons.download_outlined),
              label: Text(kIsWeb ? 'Download CSV' : 'Copy CSV'),
            ),
            if (kIsWeb)
              OutlinedButton.icon(
                onPressed: rows.isEmpty ? null : () => _copy(rows),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy CSV'),
              ),
          ]),
          const SizedBox(height: 16),
          Text(
            rows.length > shown.length ? 'Latest ${shown.length} of ${rows.length} complaints' : 'All complaints in this period',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(4),
              child: DataTable(
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Elder')),
                  DataColumn(label: Text('District')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Risk')),
                ],
                rows: [
                  for (final r in shown)
                    DataRow(cells: [
                      DataCell(Text('${r['id']}')),
                      DataCell(Text(fmtDate(r['created_at']))),
                      DataCell(Text('${r['elder_name'] ?? '-'}')),
                      DataCell(Text('${r['elder_district'] ?? '-'}')),
                      DataCell(Text(pretty(r['category']))),
                      DataCell(Text(pretty(r['status']))),
                      DataCell(Text(pretty(r['risk_level']))),
                    ]),
                ],
              ),
            ),
          ),
        ]);
      },
    ),
  );
}
