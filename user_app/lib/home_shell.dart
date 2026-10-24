import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'add_tab.dart';
import 'chats_tab.dart';
import 'home_tab.dart';
import 'presence.dart';
import 'profile_tab.dart';
import 'rooms_tab.dart';
import 'select_class.dart';
import 'settings_tab.dart';

/// Placeholder shell with the bottom navigation bar. Real screens come next.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int i = 0;

  @override
  void initState() {
    super.initState();
    Presence.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClass());
  }

  @override
  void dispose() {
    Presence.stop();
    super.dispose();
  }

  Future<void> _checkClass() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/${u.uid}/profile')
          .get();
      final v = snap.value;
      final has = v is Map && v['course'] != null && v['year'] != null;
      if (!has && mounted) await showSelectClassDialog(context);
    } catch (_) {
      // offline: try again next time Home opens
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeTab(),
      const ChatsTab(),
      const RoomsTab(),
      const AddTab(),
      ProfilePage(uid: FirebaseAuth.instance.currentUser!.uid, tab: true),
      const SettingsTab(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.person_add_alt), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'More'),
        ],
      ),
    );
  }
}
