import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'room_session.dart';
import 'voice_room_page.dart';

/// List of all live voice rooms + create / join by code + invites.
final Set<String> _pendingCleanup = {};

/// A room with no host/admin online is removed from the server after a short grace period.
void _scheduleCleanup(String id) {
  if (!_pendingCleanup.add(id)) return;
  Timer(const Duration(seconds: 15), () async {
    try {
      final h = await rtdb.ref('voiceRooms/$id/hosts').get();
      final st = await rtdb.ref('voiceRooms/$id/seats').get();
      if (!h.exists && !st.exists) {
        try {
          await rtdb.ref('voiceGifts/$id').remove();
        } catch (_) {}
        await rtdb.ref('voiceChat/$id').remove();
        await rtdb.ref('voiceRooms/$id').remove();
      }
    } catch (_) {}
    _pendingCleanup.remove(id);
  });
}

class VoiceRoomsPage extends StatelessWidget {
  const VoiceRoomsPage({super.key});

  Future<void> _create(BuildContext context) async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Naya Voice Room'),
        content: TextField(
          controller: ctl,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Room name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ref = rtdb.ref('voiceRooms').push();
    try {
      await ref.set({
        'meta': {
          'name': name,
          'owner': myUid,
          'createdAt': ServerValue.timestamp,
        },
        'hosts': {myUid: true},
      });
      if (context.mounted) {
        RoomSession.open(context, ref.key!);
      }
    } catch (e) {
      if (context.mounted) msg(context, 'Could not create room: $e');
    }
  }

  Future<void> _joinByCode(BuildContext context) async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Join with code'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Paste room code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final ok = (await rtdb.ref('voiceRooms/$code/meta').get()).exists;
      if (!context.mounted) return;
      if (!ok) {
        msg(context, 'Room not found');
        return;
      }
      RoomSession.open(context, code);
    } catch (e) {
      if (context.mounted) msg(context, 'Could not open room: $e');
    }
  }

  Widget _invites(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: rtdb.ref('voiceInvites/$myUid').onValue,
        builder: (c, s) {
          final v = s.data?.snapshot.value;
          if (v is! Map || v.isEmpty) return const SizedBox.shrink();
          final cs = Theme.of(c).colorScheme;
          return Column(children: [
            for (final e in v.entries)
              if (e.value is Map)
                Card(
                  color: cs.primaryContainer,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: ListTile(
                    leading: const Icon(Icons.mail),
                    title: UserBuilder(
                      uid: '${e.value['from']}',
                      builder: (c, p) => Text(
                          '${displayName(p)} invited you to "${e.value['name'] ?? 'room'}"'),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Hatao',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            rtdb.ref('voiceInvites/$myUid/${e.key}').remove(),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final id = '${e.key}';
                          await rtdb.ref('voiceInvites/$myUid/$id').remove();
                          if (!c.mounted) return;
                          final ok =
                              (await rtdb.ref('voiceRooms/$id/meta').get()).exists;
                          if (!c.mounted) return;
                          if (!ok) {
                            msg(c, 'This room is already closed');
                            return;
                          }
                          RoomSession.open(c, id);
                        },
                        child: const Text('Join'),
                      ),
                    ]),
                  ),
                ),
          ]);
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Voice Rooms'),
          actions: [
            IconButton(
                tooltip: 'Join with code',
                onPressed: () => _joinByCode(context),
                icon: const Icon(Icons.keyboard)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add),
          label: const Text('Create room'),
        ),
        body: Column(children: [
          _invites(context),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: rtdb.ref('voiceRooms').onValue,
              builder: (c, s) {
                if (s.hasError) {
                  return Center(
                      child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load rooms: ${s.error}',
                        textAlign: TextAlign.center),
                  ));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final v = s.data!.snapshot.value;
                final rooms = <MapEntry<String, Map>>[];
                if (v is Map) {
                  v.forEach((k, r) {
                    if (r is Map && r['meta'] is Map) {
                      final live = r['hosts'] is Map && (r['hosts'] as Map).isNotEmpty;
                      if (live) {
                        rooms.add(MapEntry('$k', r));
                      } else {
                        _scheduleCleanup('$k');
                      }
                    }
                  });
                }
                rooms.sort((a, b) =>
                    ((b.value['meta']['createdAt'] ?? 0) as num)
                        .compareTo((a.value['meta']['createdAt'] ?? 0) as num));
                if (rooms.isEmpty) {
                  return const Center(
                      child: Text('No rooms yet. Create the first one!'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: rooms.length,
                  itemBuilder: (c, i) {
                    final id = rooms[i].key;
                    final r = rooms[i].value;
                    final meta = r['meta'] as Map;
                    final seats = r['seats'] is Map ? (r['seats'] as Map).length : 0;
                    final listeners =
                        r['members'] is Map ? (r['members'] as Map).length : 0;
                    final watching = r['watch'] is Map;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Icon(watching ? Icons.ondemand_video : Icons.mic)),
                        title: Text('${meta['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: UserBuilder(
                          uid: '${meta['owner']}',
                          builder: (c, p) => Text(
                              'Host: ${displayName(p)}  •  $seats/8 seats  •  $listeners online'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => RoomSession.open(context, id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
