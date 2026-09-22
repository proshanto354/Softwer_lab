import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'awareness_screen.dart';
import 'complaint_form_screen.dart';
import 'elders_screen.dart';
import 'my_complaints_screen.dart';
import 'notifications_screen.dart';
import 'sos_screen.dart';
import 'wellbeing_screen.dart';

class UserHome extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserHome({super.key, required this.user});
  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
    // Checks for case updates every 45 seconds while the app is open
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    try {
      final r = await Api.post('/notifications/sync', {});
      if (mounted) setState(() => _unread = (r['unread'] as num).toInt());
    } catch (_) {
      // notifications are best-effort
    }
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final isElder = widget.user['role'] == 'elder';
    final name = '${widget.user['name'] ?? ''}';
    final roleLabel = pretty('${widget.user['role']}');

    final tiles = <_Tile>[
      _Tile(isElder ? 'Request help' : 'Report neglect', Icons.report_problem_outlined,
              () => _go(const ComplaintFormScreen())),
      _Tile('My complaints', Icons.track_changes_outlined, () => _go(const MyComplaintsScreen())),
      _Tile('Elder profiles', Icons.elderly_outlined, () => _go(const EldersScreen())),
      _Tile('Monthly check', Icons.favorite_border, () => _go(const WellbeingScreen())),
      _Tile('Know your rights', Icons.menu_book_outlined, () => _go(const AwarenessScreen())),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shomman'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _go(const NotificationsScreen()),
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.notifications_outlined),
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
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: _sync,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  ProfileHeader(
                    name: name.isEmpty ? 'there' : name,
                    roleLabel: roleLabel,
                    subtitle: 'Your reports are private — you can stay anonymous.',
                  ),
                  const SizedBox(height: 20),
                  _SosBanner(onTap: () => _go(const SosScreen())),
                  const SizedBox(height: 24),
                  SectionHeader(title: isElder ? 'What do you need?' : 'What would you like to do?'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: tiles
                        .map((t) => FeatureCard(label: t.label, icon: t.icon, onTap: t.onTap))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  _EmergencyFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Prominent, unmissable emergency-help entry point at the top of the home
/// screen — kept visually distinct (red, larger) from ordinary features
/// since it is a time-critical action.
class _SosBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SosBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: const Icon(Icons.sos, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SOS — Emergency help',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Tap if someone is in immediate danger',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ]),
      ),
    ),
  );
}

class _EmergencyFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.infoBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(children: [
      Icon(Icons.info_outline, color: AppColors.info, size: 20),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          'In a life-threatening emergency, always call 999 first.',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        ),
      ),
    ]),
  );
}

class _Tile {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _Tile(this.label, this.icon, this.onTap);
}
