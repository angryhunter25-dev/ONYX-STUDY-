import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'main.dart' show db, toast, confirm;

/// Owner control of the voice rooms. Rooms are stored in the ONYX database
/// under `watch/`, so the owner's normal admin login is enough.
class RoomsAdminPage extends StatelessWidget {
  const RoomsAdminPage({super.key});
  @override
  Widget build(BuildContext context) => const _RoomList();
}

class _RoomList extends StatefulWidget {
  const _RoomList();
  @override
  State<_RoomList> createState() => _RoomListState();
}

class _RoomListState extends State<_RoomList> {
  final Set<String> sel = {};
  bool get selecting => sel.isNotEmpty;

  int _count(dynamic v) => v is Map ? v.length : 0;

  Future<void> deleteSelected(Map<String, Map> rooms) async {
    final n = sel.length;
    if (!await confirm(context, '$n room delete karne hain?')) return;
    final ups = <String, Object?>{};
    for (final id in sel) {
      ups['watch/rooms/$id'] = null;
      final m = rooms[id]?['members'];
      if (m is Map) {
        for (final u in m.keys) {
          ups['watch/userRooms/$u/$id'] = null;
        }
      }
    }
    try {
      await db.ref().update(ups);
      if (mounted) {
        setState(sel.clear);
        toast(context, '$n room delete ho gaye');
      }
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && selecting) setState(sel.clear);
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Rooms')),
          body: StreamBuilder<DatabaseEvent>(
            stream: db.ref('watch/rooms').onValue,
            builder: (c, s) {
              if (s.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Permission nahi mili. Firebase Rules me naya database.rules.json Publish karo '
                        'aur check karo ki is account ka UID admins me true hai.',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final v = s.data!.snapshot.value;
              final rooms = <String, Map>{};
              if (v is Map) {
                v.forEach((k, val) {
                  if (val is Map) rooms[k.toString()] = val;
                });
              }
              if (rooms.isEmpty) {
                return const Center(child: Text('Abhi koi room nahi'));
              }
              final keys = rooms.keys.toList();
              final allSelected = sel.containsAll(keys);
              return Column(children: [
                if (selecting)
                  Material(
                    color: Theme.of(c).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(children: [
                        IconButton(
                            tooltip: 'Cancel',
                            onPressed: () => setState(sel.clear),
                            icon: const Icon(Icons.close)),
                        Text('${sel.length} selected',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                            onPressed: () => setState(() {
                                  if (allSelected) {
                                    sel.clear();
                                  } else {
                                    sel.addAll(keys);
                                  }
                                }),
                            child: Text(
                                allSelected ? 'Unselect all' : 'Select all')),
                        IconButton(
                            tooltip: 'Delete selected',
                            onPressed: () => deleteSelected(rooms),
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent)),
                      ]),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Delete ke liye room ko dabake pakdo',
                        style: TextStyle(fontSize: 12)),
                  ),
                Expanded(
                  child: ListView(children: [
                    for (final k in keys)
                      ListTile(
                        selected: sel.contains(k),
                        selectedTileColor: Theme.of(c)
                            .colorScheme
                            .primary
                            .withOpacity(0.15),
                        leading: selecting
                            ? Checkbox(
                                value: sel.contains(k),
                                onChanged: (_) => setState(() {
                                      sel.contains(k)
                                          ? sel.remove(k)
                                          : sel.add(k);
                                    }))
                            : Icon(rooms[k]!['locked'] == true
                                ? Icons.lock
                                : Icons.meeting_room),
                        title: Text('${rooms[k]!['name'] ?? k}'),
                        subtitle: Text(
                            '${_count(rooms[k]!['members'])} members, ${_count(rooms[k]!['online'])} online'),
                        trailing:
                            selecting ? null : const Icon(Icons.chevron_right),
                        onLongPress: () => setState(() => sel.add(k)),
                        onTap: () {
                          if (selecting) {
                            setState(() {
                              sel.contains(k) ? sel.remove(k) : sel.add(k);
                            });
                          } else {
                            Navigator.push(
                                c,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        _RoomDetail(roomId: k)));
                          }
                        },
                      ),
                  ]),
                ),
              ]);
            },
          ),
        ),
      );
}

class _Name extends StatelessWidget {
  final String uid;
  const _Name({required this.uid});
  @override
  Widget build(BuildContext context) => FutureBuilder<DataSnapshot>(
        future: db.ref('watch/users/$uid/username').get(),
        builder: (c, s) {
          final v = s.data?.value;
          return Text(v == null ? uid : '@$v');
        },
      );
}

class _RoomDetail extends StatelessWidget {
  final String roomId;
  const _RoomDetail({required this.roomId});

  DatabaseReference get r => db.ref('watch/rooms/$roomId');

  Future<void> _run(BuildContext c, Future<void> Function() f, String ok) async {
    try {
      await f();
      if (c.mounted) toast(c, ok);
    } catch (e) {
      if (c.mounted) toast(c, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: r.onValue,
        builder: (c, s) {
          final v = s.data?.snapshot.value;
          if (s.hasData && v is! Map) {
            return Scaffold(
                appBar: AppBar(title: const Text('Room')),
                body: const Center(child: Text('Room delete ho chuka hai')));
          }
          final room = v is Map ? v : <dynamic, dynamic>{};
          final members = <String>[
            if (room['members'] is Map)
              ...(room['members'] as Map).keys.map((e) => e.toString())
          ];
          final online = room['online'] is Map ? room['online'] as Map : {};
          final locked = room['locked'] == true;
          return Scaffold(
            appBar: AppBar(title: Text('${room['name'] ?? 'Room'}')),
            body: ListView(children: [
              ListTile(
                  title: const Text('Owner'),
                  subtitle: room['owner'] == null
                      ? const Text('-')
                      : _Name(uid: '${room['owner']}')),
              SwitchListTile(
                title: const Text('Room lock'),
                subtitle: const Text('Lock ho to naya koi join nahi kar sakta'),
                value: locked,
                onChanged: (x) =>
                    _run(c, () => r.child('locked').set(x), 'Ho gaya'),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Room chat saaf karo'),
                onTap: () async {
                  if (await confirm(c, 'Room chat delete karni hai?')) {
                    if (c.mounted) {
                      await _run(c, () => r.child('chat').remove(), 'Chat saaf');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.stop_screen_share),
                title: const Text('Screen / video band karo'),
                onTap: () => _run(c, () async {
                  await r.child('browser').remove();
                  await r.child('bvideo').remove();
                }, 'Band kar diya'),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Members (${members.length}/8)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final m in members)
                ListTile(
                  leading: Icon(Icons.circle,
                      size: 14,
                      color: online[m] == true ? Colors.green : Colors.grey),
                  title: _Name(uid: m),
                  subtitle: m == '${room['owner']}' ? const Text('owner') : null,
                  trailing: m == '${room['owner']}'
                      ? null
                      : IconButton(
                          tooltip: 'Kick',
                          icon: const Icon(Icons.person_remove,
                              color: Colors.redAccent),
                          onPressed: () async {
                            if (await confirm(c, 'Is member ko nikalna hai?')) {
                              if (!c.mounted) return;
                              await _run(c, () => db.ref().update({
                                    'watch/rooms/$roomId/kicked/$m': true,
                                    'watch/rooms/$roomId/members/$m': null,
                                    'watch/rooms/$roomId/online/$m': null,
                                    'watch/rooms/$roomId/voice/peers/$m': null,
                                    'watch/userRooms/$m/$roomId': null,
                                  }), 'Nikal diya');
                            }
                          }),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Room delete karo'),
                  onPressed: () async {
                    if (await confirm(c, 'Poora room delete karna hai?')) {
                      if (!c.mounted) return;
                      await _run(c, () => db.ref().update({
                            'watch/rooms/$roomId': null,
                            for (final m in members) 'watch/userRooms/$m/$roomId': null,
                          }), 'Room delete ho gaya');
                    }
                  },
                ),
              ),
            ]),
          );
        },
      );
}
