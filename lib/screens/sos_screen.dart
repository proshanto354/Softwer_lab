import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _msg = TextEditingController();
  List<dynamic> _elders = [];
  int? _elderId;
  bool _busy = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    Api.get('/elders').then((l) {
      if (mounted) setState(() => _elders = l as List<dynamic>);
    }).catchError((_) {});
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await Api.post('/sos', {'elder_id': _elderId, 'message': _msg.text.trim()});
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('SOS Emergency Help')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_sent) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                ),
                const SizedBox(height: 18),
                Text('Your SOS request has been sent to the welfare office.',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('If someone is in immediate danger, also call 999.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use this only if an elderly person is in urgent danger or needs immediate help.',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                if (_elders.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: _elderId,
                    decoration: const InputDecoration(
                        labelText: 'Who needs help? (optional)', prefixIcon: Icon(Icons.elderly_outlined)),
                    items:
                    _elders.map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name']))).toList(),
                    onChanged: (v) => setState(() => _elderId = v),
                  ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _msg,
                  label: 'Short message (optional)',
                  maxLines: 3,
                  prefixIcon: Icons.chat_bubble_outline,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 60,
                  child: PrimaryButton(
                    label: 'SEND SOS',
                    loading: _busy,
                    onPressed: _send,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:999')),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call 999 (national emergency)'),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}
