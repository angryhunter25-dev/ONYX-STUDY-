import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

/// Writes presence/<uid> = {name, username, joinedAt, online, lastActive}
/// so the owner app can see who signed up and who is active.
class Presence with WidgetsBindingObserver {
  Presence._();
  static final Presence _i = Presence._();
  static void start() => _i._start();
  static void stop() => _i._stop();

  bool _running = false;
  DatabaseReference? _ref;
  StreamSubscription<DatabaseEvent>? _conn;
  Timer? _tick;
  bool _connected = false;

  Future<void> _start() async {
    if (_running) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    _running = true;
    _ref = FirebaseDatabase.instance.ref('presence/${u.uid}');
    WidgetsBinding.instance.addObserver(this);

    _conn = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen((e) async {
      _connected = e.snapshot.value == true;
      if (_connected) await _goOnline();
    });
    _tick = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_connected) _touch();
    });
  }

  Future<void> _goOnline() async {
    final u = FirebaseAuth.instance.currentUser;
    final r = _ref;
    if (u == null || r == null) return;
    try {
      await r.onDisconnect().update(
          {'online': false, 'lastActive': ServerValue.timestamp});
      String name = '', username = '';
      try {
        final s =
            await FirebaseDatabase.instance.ref('users/${u.uid}/profile').get();
        final v = s.value;
        if (v is Map) {
          name = '${v['name'] ?? ''}';
          username = '${v['username'] ?? ''}';
        }
      } catch (_) {}
      await r.update({
        'name': name,
        'username': username,
        'joinedAt': u.metadata.creationTime?.millisecondsSinceEpoch,
        'online': true,
        'lastActive': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  Future<void> _touch() async {
    try {
      await _ref?.update(
          {'online': true, 'lastActive': ServerValue.timestamp});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!_running) return;
    if (s == AppLifecycleState.resumed) {
      _touch();
    } else if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.detached) {
      _ref
          ?.update({'online': false, 'lastActive': ServerValue.timestamp})
          .catchError((_) {});
    }
  }

  Future<void> _stop() async {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    await _conn?.cancel();
    try {
      await _ref
          ?.update({'online': false, 'lastActive': ServerValue.timestamp});
    } catch (_) {}
    _ref = null;
  }
}
