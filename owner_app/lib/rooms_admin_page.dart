import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'main.dart' show db, toast, confirm;

/// Owner control of the voice rooms (data lives in `voiceRooms/`).
class RoomsAdminPage extends StatefulWidget {
  const RoomsAdminPage({super.key});
  @override
  State<RoomsAdminPage> createState() => _RoomsAdminPageState();
}

class _RoomsAdminPageState extends State<RoomsAdminPage> {
  final Set<String> sel = {};
  bool get selecting => sel.isNotEmpty;

  int _count(dynamic v) => v is Map ? v.length : 0;

  Future<void> deleteSelected() async {
    final n = sel.length;
    if (!await confirm(context, '$n room delete karne hain?')) return;
    final ups = <String, Object?>{};
    for (final id in sel) {
      ups['voiceRooms/$id'] = null;
      ups['voiceChat/$id'] = null;
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
          appBar: AppBar(title: const Text('Voice Rooms')),
          body: StreamBuilder<DatabaseEvent>(
            stream: db.ref('voiceRooms').onValue,
            builder: (c, s) {
              if (s.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Permission nahi mili. Naya database.rules.json Firebase me Publish karo.',
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
                  if (val is Map && val['meta'] is Map) rooms['$k'] = val;
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(children: [
                        IconButton(
                            tooltip: 'Cancel',
                            onPressed: () => setState(sel.clear),
                            icon: const Icon(Icons.close)),
                        Text('${sel.length} selected',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                            onPressed: () => setState(() {
                                  if (allSelected) {
                                    sel.clear();
                                  } else {
                                    sel.addAll(keys);
                                  }
                                }),
                            child:
                                Text(allSelected ? 'Unselect all' : 'Select all')),
                        IconButton(
                            tooltip: 'Delete selected',
                            onPressed: deleteSelected,
                            icon: const Icon(Icons.delete, color: Colors.redAccent)),
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
                        selectedTileColor:
                            Theme.of(c).colorScheme.primary.withOpacity(0.15),
                        leading: selecting
                            ? Checkbox(
                                value: sel.contains(k),
                                onChanged: (_) => setState(() {
                                      sel.contains(k) ? sel.remove(k) : sel.add(k);
                                    }))
                            : Icon(rooms[k]!['watch'] is Map
                                ? Icons.ondemand_video
                                : Icons.mic),
                        title: Text('${(rooms[k]!['meta'] as Map)['name'] ?? k}'),
                        subtitle: Text(
                            '${_count(rooms[k]!['seats'])}/8 seats, ${_count(rooms[k]!['members'])} online'),
                        trailing: selecting ? null : const Icon(Icons.chevron_right),
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
                                    builder: (_) => _RoomDetail(roomId: k)));
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
        future: db.ref('users/$uid/profile').get(),
        builder: (c, s) {
          final v = s.data?.value;
          if (v is Map) {
            final n = '${v['name'] ?? ''}'.trim();
            final u = '${v['username'] ?? ''}';
            if (n.isNotEmpty) return Text(n);
            if (u.isNotEmpty) return Text('@$u');
          }
          return Text(uid);
        },
      );
}

class _RoomDetail extends StatelessWidget {
  final String roomId;
  const _RoomDetail({required this.roomId});

  DatabaseReference get r => db.ref('voiceRooms/$roomId');

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
          if (s.hasData && (v is! Map || v['meta'] is! Map)) {
            return Scaffold(
                appBar: AppBar(title: const Text('Room')),
                body: const Center(child: Text('Room delete ho chuka hai')));
          }
          final room = v is Map ? v : <dynamic, dynamic>{};
          final meta = room['meta'] is Map ? room['meta'] as Map : {};
          final seats = <String, Map>{};
          if (room['seats'] is Map) {
            (room['seats'] as Map).forEach((k, val) {
              if (val is Map) seats['$k'] = val;
            });
          }
          final hasVideo = room['watch'] is Map;
          return Scaffold(
            appBar: AppBar(title: Text('${meta['name'] ?? 'Room'}')),
            body: ListView(children: [
              ListTile(
                  title: const Text('Host'),
                  subtitle: meta['owner'] == null
                      ? const Text('-')
                      : _Name(uid: '${meta['owner']}')),
              ListTile(
                title: const Text('Room code'),
                subtitle: SelectableText(roomId),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Room chat saaf karo'),
                onTap: () async {
                  if (await confirm(c, 'Room chat delete karni hai?')) {
                    if (c.mounted) {
                      await _run(c, () => db.ref('voiceChat/$roomId').remove(),
                          'Chat saaf');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.stop_screen_share),
                title: Text(hasVideo ? 'Video band karo' : 'Koi video nahi chal raha'),
                enabled: hasVideo,
                onTap: () => _run(c, () => r.child('watch').remove(), 'Band kar diya'),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Seats (${seats.length}/8)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final e in seats.entries)
                ListTile(
                  leading: Icon(
                      (e.value['selfMuted'] == true || e.value['hostMuted'] == true)
                          ? Icons.mic_off
                          : Icons.mic,
                      color: Colors.green),
                  title: _Name(uid: '${e.value['uid']}'),
                  subtitle: Text('Seat ${(int.tryParse(e.key) ?? 0) + 1}'),
                  trailing: IconButton(
                      tooltip: 'Seat se hatao',
                      icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                      onPressed: () => _run(
                          c, () => r.child('seats/${e.key}').remove(), 'Hata diya')),
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
                            'voiceRooms/$roomId': null,
                            'voiceChat/$roomId': null,
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
