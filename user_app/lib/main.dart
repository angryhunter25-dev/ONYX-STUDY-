import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'firebase_options.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'theme.dart';
import 'username_screen.dart';
import 'welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  await loadSettings();
  runApp(const OnyxApp());
}

class OnyxApp extends StatelessWidget {
  const OnyxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return LiveTheme(
      builder: (theme, cfg) => MaterialApp(
        title: 'ONYX',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Login -> "You're in" animation -> username (new users) -> Home
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool welcomed = FirebaseAuth.instance.currentUser != null;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) return const _Loader();
        final u = s.data;
        if (u == null) {
          welcomed = false;
          return const LoginScreen();
        }
        if (!welcomed) {
          return WelcomeScreen(
              user: u, onDone: () => setState(() => welcomed = true));
        }
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance
              .ref('users/${u.uid}/profile/username')
              .onValue,
          builder: (c, p) {
            if (!p.hasData) return const _Loader();
            return p.data!.snapshot.value == null
                ? const UsernameScreen()
                : const HomeShell();
          },
        );
      },
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
