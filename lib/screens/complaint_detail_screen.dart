import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

const _statuses = ['submitted', 'under_review', 'verified', 'in_progress', 'visit_scheduled', 'resolved', 'rejected'];
const _risks = ['unassigned', 'low', 'medium', 'high', 'critical'];

/// Shared by reporters (staff: false -> tracking) and officers (staff: true -> management).
class ComplaintDetailScreen extends StatefulWidget {
  final int id;
  final bool staff;
  final VoidCallback? onChanged; // lets the officer's case list refresh after an action
  const ComplaintDetailScreen({super.key, required this.id, required this.staff, this.onChanged});
  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  final _note = TextEditingController();

  String get _base => widget.staff ? '/admin/complaints/${widget.id}' : '/complaints/${widget.id}';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(await Api.get(_base));
  void _reload() => setState(() => _future = _load());

  Future<void> _act(Future<dynamic> Function() action, String done) async {
    try {
      await action();
      _note.clear();
      if (mounted) snack(context, done);
      _reload();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
  }

  Future<void> _scheduleVisit() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null) return;
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _act(
          () => Api.post('/admin/complaints/${widget.id}/visits', {
        'scheduled_at': when.toUtc().toIso8601String(),
        'notes': _note.text.trim(),
      }),
      'Visit scheduled',
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...children,
      ]),
    ),
  );

  Widget _row(String k, dynamic v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Expanded(child: Text(v == null || '$v'.isEmpty ? '-' : '$v')),
    ]),
  );

  Widget _evidence(List<dynamic> list) {
    if (list.isEmpty) {
      return const Text('No evidence attached', style: TextStyle(color: AppColors.textSecondary));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final ev in list) _EvidenceTile(ev: Map<String, dynamic>.from(ev as Map)),
    ]);
  }

  Widget _actions(Map<String, dynamic> c) {
    final status = c['status'] as String;
    final risk = c['risk_level'] as String;
    return _section('Officer actions', [
      CustomTextField(controller: _note, label: 'Note (shown on the case timeline)', maxLines: 2),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _act(() => Api.patch('/admin/complaints/${widget.id}/verify',
                {'verified': true, 'note': _note.text.trim()}), 'Case verified'),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Verify'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SecondaryButton(
            label: 'Reject',
            icon: Icons.block,
            color: AppColors.error,
            onPressed: () => _act(() => Api.patch('/admin/complaints/${widget.id}/verify',
                {'verified': false, 'note': _note.text.trim()}), 'Case rejected'),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: risk,
        decoration: const InputDecoration(labelText: 'Risk level'),
        items: _risks.map((r) => DropdownMenuItem(value: r, child: Text(pretty(r)))).toList(),
        onChanged: (v) {
          if (v != null && v != risk) {
            _act(() => Api.patch('/admin/complaints/${widget.id}/risk', {'risk_level': v}), 'Risk updated');
          }
        },
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: status,
        decoration: const InputDecoration(labelText: 'Update status'),
        items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(pretty(s)))).toList(),
        onChanged: (v) {
          if (v != null && v != status) {
            _act(() => Api.patch('/admin/complaints/${widget.id}/status',
                {'status': v, 'note': _note.text.trim()}), 'Status updated');
          }
        },
      ),
      const SizedBox(height: 14),
      SecondaryButton(label: 'Schedule welfare visit', icon: Icons.event_available_outlined, onPressed: _scheduleVisit),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text('Complaint #${widget.id}')),
    body: AsyncBody<Map<String, dynamic>>(
      future: _future,
      onRetry: _reload,
      builder: (c) {
        final updates = (c['updates'] as List).where((u) => u['status'] != 'risk_updated' || widget.staff).toList();
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _section('Case', [
                    Wrap(spacing: 8, children: [StatusPill(c['status']), RiskPill(c['risk_level'])]),
                    const SizedBox(height: 10),
                    _row('Category', pretty(c['category'])),
                    _row('Submitted', fmtDate(c['created_at'], time: true)),
                    if (widget.staff)
                      _row(
                        'Reporter',
                        c['is_anonymous'] == 1 || c['is_anonymous'] == true
                            ? 'Anonymous'
                            : '${c['reporter_name'] ?? '-'} (${pretty(c['reporter_role'])}) ${c['reporter_phone'] ?? ''}',
                      ),
                    const SizedBox(height: 8),
                    Text(c['description']),
                  ]),
                  _section('Elder', [
                    _row('Name', c['elder_name']),
                    _row('Age', c['elder_age']),
                    _row('Address', c['elder_address']),
                    _row('District', c['elder_district']),
                    _row('Phone', c['elder_phone']),
                    _row('Emergency', c['elder_emergency_contact']),
                    if (widget.staff) _row('Health notes', c['elder_health_notes']),
                  ]),
                  _section('Evidence', [_evidence(c['evidence'] as List)]),
                  if ((c['visits'] as List).isNotEmpty)
                    _section('Welfare visits', [
                      for (final v in c['visits'])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              v['completed'] == 1 || v['completed'] == true ? Icons.check_circle : Icons.schedule,
                              color: v['completed'] == 1 || v['completed'] == true
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            title: Text(fmtDate(v['scheduled_at'], time: true)),
                            subtitle: Text('Officer: ${v['officer_name']}${v['notes'] != null ? '\n${v['notes']}' : ''}'),
                          ),
                        ),
                    ]),
                  _section('Progress', [
                    for (final u in updates)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.circle, size: 10, color: AppColors.primary),
                          title: Text(pretty(u['status']), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${fmtDate(u['created_at'], time: true)}${u['note'] != null ? '\n${u['note']}' : ''}'),
                        ),
                      ),
                  ]),
                  if (widget.staff) _actions(c),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// One photo or audio file. Files are fetched through Firebase Storage security rules
/// (only the reporter and officers/admins can read them).
class _EvidenceTile extends StatefulWidget {
  final Map<String, dynamic> ev;
  const _EvidenceTile({required this.ev});
  @override
  State<_EvidenceTile> createState() => _EvidenceTileState();
}

class _EvidenceTileState extends State<_EvidenceTile> {
  Future<Uint8List?>? _bytes;

  String? get _path => widget.ev['path'] as String?;
  bool get _isPhoto => widget.ev['type'] == 'photo';

  @override
  void initState() {
    super.initState();
    if (_isPhoto && _path != null) _bytes = StorageService.bytes(_path!);
  }

  Future<void> _play() async {
    try {
      final url = _path != null ? await StorageService.downloadUrl(_path!) : '${widget.ev['url']}';
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) snack(context, 'Could not open the file');
    } catch (e) {
      if (mounted) snack(context, 'Could not open the file: $e');
    }
  }

  void _preview(Widget image) => showDialog(
    context: context,
    builder: (_) => Dialog(child: InteractiveViewer(child: image)),
  );

  Widget _thumb(Widget image) => GestureDetector(
    onTap: () => _preview(image),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 90, height: 90, child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: image)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_isPhoto) {
      return ActionChip(
        avatar: const Icon(Icons.play_circle_outline, color: AppColors.primary),
        label: const Text('Play audio'),
        onPressed: _play,
      );
    }
    if (_path == null) {
      // older complaints that stored a link instead of a path
      return _thumb(Image.network('${widget.ev['url']}'));
    }
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
              width: 90, height: 90, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final data = snap.data;
        if (snap.hasError || data == null) {
          return const SizedBox(width: 90, height: 90, child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary));
        }
        return _thumb(Image.memory(data));
      },
    );
  }
}
