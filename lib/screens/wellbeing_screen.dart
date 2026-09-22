import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({super.key});
  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  final _notes = TextEditingController();
  List<dynamic> _elders = [];
  bool _loading = true;
  int? _elderId;
  bool _meals = true;
  bool _medicine = true;
  bool _safe = true;
  bool _lonely = false;
  int _visits = 0;
  bool _busy = false;

  String get _month {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    Api.get('/elders').then((l) {
      if (!mounted) return;
      final list = l as List<dynamic>;
      setState(() {
        _elders = list;
        if (list.isNotEmpty) _elderId = list.first['id'] as int;
        _loading = false;
      });
    }).catchError((e) {
      if (mounted) {
        setState(() => _loading = false);
        snack(context, '$e');
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final r = await Api.post('/wellbeing', {
        'elder_id': _elderId,
        'month': _month,
        'meals_regular': _meals,
        'has_medicine': _medicine,
        'feels_safe': _safe,
        'feels_lonely': _lonely,
        'family_visits': _visits,
        'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      snack(context, r['flagged'] == true
          ? 'Saved. Some answers need attention - a welfare officer may follow up.'
          : 'Saved. Thank you!');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card({required List<Widget> children}) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(6), child: Column(children: children)),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.background, body: LoadingWidget());
    }
    if (_elders.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Monthly wellbeing check')),
        body: const EmptyStateWidget(
          icon: Icons.elderly_outlined,
          title: 'Add an elder profile first',
          subtitle: 'You need at least one elder profile to submit a wellbeing check.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Wellbeing check • $_month')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<int>(
                  value: _elderId,
                  decoration: const InputDecoration(labelText: 'Elder', prefixIcon: Icon(Icons.elderly_outlined)),
                  items: _elders.map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name']))).toList(),
                  onChanged: (v) => setState(() => _elderId = v),
                ),
                const SizedBox(height: 14),
                _card(children: [
                  SwitchListTile(
                      title: const Text('Getting regular meals'), value: _meals, onChanged: (v) => setState(() => _meals = v)),
                  const Divider(height: 1),
                  SwitchListTile(
                      title: const Text('Has the medicines/treatment needed'),
                      value: _medicine,
                      onChanged: (v) => setState(() => _medicine = v)),
                  const Divider(height: 1),
                  SwitchListTile(
                      title: const Text('Feels safe at home'), value: _safe, onChanged: (v) => setState(() => _safe = v)),
                  const Divider(height: 1),
                  SwitchListTile(
                      title: const Text('Often feels lonely'), value: _lonely, onChanged: (v) => setState(() => _lonely = v)),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Family visits this month'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        onPressed: _visits > 0 ? () => setState(() => _visits--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_visits', style: Theme.of(context).textTheme.titleMedium),
                      IconButton(onPressed: () => setState(() => _visits++), icon: const Icon(Icons.add_circle_outline)),
                    ]),
                  ),
                ]),
                CustomTextField(controller: _notes, label: 'Notes (optional)', maxLines: 3),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Submit check', loading: _busy, onPressed: _submit),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
