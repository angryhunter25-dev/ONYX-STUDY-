import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _ch = MethodChannel('onyx/rooms');

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _randomKey() {
  const chars =
      'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Opens the voice room screen inside ONYX. The room account is created
/// automatically from the logged-in ONYX user (no second login).
/// Returns the ONYX tab the user tapped in the room's bottom bar
/// (0-5), -1 if they just went back, or null if it could not open.
Future<int?> openRoomsScreen(BuildContext context) async {
  final u = FirebaseAuth.instance.currentUser;
  final msg = ScaffoldMessenger.of(context);
  if (u == null) return null;
  final db = FirebaseDatabase.instance;
  try {
    // Private per-user secret (only this user and admins can read it).
    final kref = db.ref('users/${u.uid}/private/roomKey');
    final ks = await kref.get();
    var key = ks.value is String ? ks.value as String : '';
    if (key.length < 16) {
      key = _randomKey();
      await kref.set(key);
    }
    var name = '', photo = '';
    try {
      final p = await db.ref('users/${u.uid}/profile').get();
      final v = p.value;
      if (v is Map) {
        name = '${v['username'] ?? ''}';
        photo = '${v['photo'] ?? ''}';
      }
    } catch (_) {}
    if (!context.mounted) return null;
    final cs = Theme.of(context).colorScheme;
    final args = <String, String>{
      'email': '${u.uid.toLowerCase()}@rooms.onyx.app',
      'pass': key,
      'username': name,
      'photo': photo.length <= 60000 ? photo : '',
      'bg': _hex(cs.surface),
      'card': _hex(cs.surfaceContainerHigh),
      'tx': _hex(cs.onSurface),
      'ac': _hex(cs.primary),
      'mut': _hex(cs.onSurfaceVariant),
      'onac': _hex(cs.onPrimary),
      'navBg': _hex(cs.surfaceContainer),
      'navFg': _hex(cs.onSurfaceVariant),
      'navSel': _hex(cs.onSurface),
      'ind': _hex(cs.secondaryContainer),
    };
    return await _ch.invokeMethod<int>('open', args);
  } catch (e) {
    msg.showSnackBar(SnackBar(content: Text('Rooms nahi khul paaya: $e')));
    return null;
  }
}

/// Placeholder shown for a moment while the room screen opens.
class RoomsTab extends StatelessWidget {
  const RoomsTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Rooms khul raha hai...'),
        ]),
      );
}
