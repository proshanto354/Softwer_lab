import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

const roleLabels = {
  'elder': 'Elderly person (I need help)',
  'family': 'Family member',
  'neighbor': 'Neighbor',
  'social_worker': 'Social worker',
  'volunteer': 'Volunteer',
};

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ProfileSetupScreen({super.key, required this.onDone});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'family';
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      snack(context, 'Please enter your name');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.post('/auth/register', {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'role': _role,
      });
      widget.onDone();
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Complete your profile'),
      actions: [
        IconButton(
          tooltip: 'Logout',
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 4),
              Text('Tell us about you', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text(
                'This helps us route reports and help requests to the right place.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              CustomTextField(controller: _name, label: 'Full name', prefixIcon: Icons.badge_outlined),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _phone,
                label: 'Phone number',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.call_outlined,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'I am a...', prefixIcon: Icon(Icons.person_outline)),
                items: roleLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 26),
              PrimaryButton(label: 'Continue', loading: _busy, onPressed: _save),
            ]),
          ),
        ),
      ),
    ),
  );
}
