import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_widgets.dart';
import 'screens/admin_home.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/user_home.dart';
import 'services/api_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: kIsWeb ? firebaseWebOptions : null);
  runApp(const ShommanApp());
}

class ShommanApp extends StatelessWidget {
  const ShommanApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Shomman',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const AuthGate(),
  );
}

/// Shows login when signed out, otherwise loads the user's profile.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: LoadingWidget(),
        );
      }
      if (snap.data == null) return const LoginScreen();
      return ProfileGate(key: ValueKey(snap.data!.uid));
    },
  );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    try {
      final me = await Api.get('/auth/me');
      PushService.register();
      return Map<String, dynamic>.from(me);
    } on ApiException catch (e) {
      if (e.status == 404) return null; // signed up in Firebase but no profile yet
      rethrow;
    }
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: LoadingWidget(),
        );
      }
      if (snap.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Shomman'), actions: [
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
          ]),
          body: ErrorStateWidget(message: 'Could not load your account.\n${snap.error}', onRetry: _reload),
        );
      }
      final user = snap.data;
      if (user == null) return ProfileSetupScreen(onDone: _reload);
      final role = user['role'] as String;
      if (role == 'officer' || role == 'admin') return AdminHome(user: user);
      return UserHome(user: user);
    },
  );
}
