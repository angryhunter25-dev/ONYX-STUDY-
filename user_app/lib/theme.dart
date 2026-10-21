import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

Color hex(String? h, Color d) {
  if (h == null || h.isEmpty) return d;
  try {
    return Color(int.parse(h.replaceFirst('#', '0xFF')));
  } catch (_) {
    return d;
  }
}

/// Rebuilds the whole app whenever the admin changes appConfig (live).
class LiveTheme extends StatelessWidget {
  final Widget Function(ThemeData theme, Map cfg) builder;
  const LiveTheme({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('appConfig').onValue,
      builder: (c, snap) {
        final cfg = (snap.data?.snapshot.value as Map?) ?? {};
        final t = (cfg['theme'] as Map?) ?? {};
        final theme = ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: hex(t['primary'], const Color(0xFF7C5CFF)),
          useMaterial3: true,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: hex(t['buttonColor'], const Color(0xFF7C5CFF)),
              foregroundColor: hex(t['buttonTextColor'], Colors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            ),
          ),
        );
        return builder(theme, cfg);
      },
    );
  }
}
