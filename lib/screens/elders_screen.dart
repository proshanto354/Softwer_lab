import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class EldersScreen extends StatefulWidget {
  const EldersScreen({super.key});
  @override
  State<EldersScreen> createState() => _EldersScreenState();
}

class _EldersScreenState extends State<EldersScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async => await Api.get('/elders') as List<dynamic>;
  void _reload() => setState(() => _future = _load());

  Future<void> _open([Map<String, dynamic>? elder]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ElderFormScreen(elder: elder)),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Elder profiles')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _open(),
      icon: const Icon(Icons.add),
      label: const Text('Add elder'),
    ),
    body: AsyncBody<List<dynamic>>(
      future: _future,
      onRetry: _reload,
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.elderly_outlined,
            title: 'No elder profiles yet',
            subtitle: 'Add the elderly person you want to help or report for.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 90, top: 4),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = Map<String, dynamic>.from(list[i]);
            final sub = [
              if (e['age'] != null) '${e['age']} yrs',
              if (e['district'] != null) e['district'],
            ].join(' • ');
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.surfaceAlt,
                child: Icon(Icons.person_outline, color: AppColors.textSecondary),
              ),
              title: Text(e['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: sub.isEmpty ? null : Text(sub),
              trailing: const Icon(Icons.edit_outlined, color: AppColors.textTertiary),
              onTap: () => _open(e),
            );
          },
        );
      },
    ),
  );
}

class ElderFormScreen extends StatefulWidget {
  final Map<String, dynamic>? elder;
  const ElderFormScreen({super.key, this.elder});
  @override
  State<ElderFormScreen> createState() => _ElderFormScreenState();
}

class _ElderFormScreenState extends State<ElderFormScreen> {
  late final Map<String, TextEditingController> _c;
  String? _gender;
  bool _busy = false;

  static const _fields = ['name', 'age', 'address', 'district', 'phone', 'emergency_contact', 'health_notes'];

  @override
  void initState() {
    super.initState();
    final e = widget.elder ?? {};
    _c = {for (final f in _fields) f: TextEditingController(text: e[f]?.toString() ?? '')};
    _gender = e['gender'];
  }

  Future<void> _save() async {
    if (_c['name']!.text.trim().isEmpty) {
      snack(context, 'Name is required');
      return;
    }
    setState(() => _busy = true);
    final body = {for (final f in _fields) f: _c[f]!.text.trim(), 'gender': _gender};
    try {
      if (widget.elder == null) {
        await Api.post('/elders', body);
      } else {
        await Api.put('/elders/${widget.elder!['id']}', body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label, {TextInputType? type, int lines = 1, IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: CustomTextField(
      controller: _c[key]!,
      label: label,
      keyboardType: type,
      maxLines: lines,
      prefixIcon: icon,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text(widget.elder == null ? 'Add elder' : 'Edit elder')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _field('name', 'Full name *', icon: Icons.badge_outlined),
              _field('age', 'Age', type: TextInputType.number, icon: Icons.cake_outlined),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
              _field('address', 'Address / village', lines: 2, icon: Icons.home_outlined),
              _field('district', 'District', icon: Icons.map_outlined),
              _field('phone', 'Phone', type: TextInputType.phone, icon: Icons.call_outlined),
              _field('emergency_contact', 'Emergency contact', icon: Icons.contact_phone_outlined),
              _field('health_notes', 'Health notes (optional)', lines: 3, icon: Icons.notes_outlined),
              const SizedBox(height: 8),
              PrimaryButton(label: 'Save', loading: _busy, onPressed: _save),
            ]),
          ),
        ),
      ),
    ),
  );
}
