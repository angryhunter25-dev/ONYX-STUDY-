import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'add_tab.dart';
import 'animated_bg.dart';
import 'chats_tab.dart';
import 'home_tab.dart';
import 'presence.dart';
import 'profile_tab.dart';
import 'room_session.dart';
import 'rooms_tab.dart';
import 'select_class.dart';
import 'settings_tab.dart';
import 'voice_room_page.dart';

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
      final has = v is Map && v['course'] != null && v['year'] != null && v['subjectsChosen'] == true;
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
    final scaffold = Scaffold(
      body: AnimatedTabBackground(
        index: i,
        child: Theme(
          data: Theme.of(context).copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: SafeArea(child: pages[i]),
        ),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const _MiniRoomBar(),
        NavigationBar(
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
      ]),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([RoomSession.roomId, RoomSession.expanded]),
      builder: (context, _) {
        final id = RoomSession.roomId.value;
        final open = RoomSession.expanded.value;
        return PopScope(
          // back button minimizes an open room instead of leaving the app
          canPop: !(id != null && open),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) RoomSession.minimize();
          },
          child: Stack(children: [
            Positioned.fill(child: scaffold),
            if (id != null)
              Positioned.fill(
                child: Offstage(
                  offstage: !open,
                  child: VoiceRoomPage(key: ValueKey(id), roomId: id),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _MiniRoomBar extends StatelessWidget {
  const _MiniRoomBar();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([RoomSession.roomId, RoomSession.expanded]),
      builder: (context, _) {
        final id = RoomSession.roomId.value;
        if (id == null || RoomSession.expanded.value) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Material(
          color: cs.primaryContainer,
          child: InkWell(
            onTap: RoomSession.expand,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                const Icon(Icons.graphic_eq),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance.ref('voiceRooms/$id/meta/name').onValue,
                    builder: (c, s) => Text(
                      '${s.data?.snapshot.value ?? 'Voice room'}  •  tap to return',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                    tooltip: 'Leave room',
                    onPressed: RoomSession.exit,
                    icon: const Icon(Icons.close)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
