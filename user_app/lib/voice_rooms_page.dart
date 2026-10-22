import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'voice_room_page.dart';

/// List of all live voice rooms + create new room.
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
          decoration: const InputDecoration(hintText: 'Room ka naam'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: const Text('Banao')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ref = rtdb.ref('voiceRooms').push();
    try {
      await ref.child('meta').set({
        'name': name,
        'owner': myUid,
        'createdAt': ServerValue.timestamp,
      });
      if (context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => VoiceRoomPage(roomId: ref.key!)));
      }
    } catch (e) {
      if (context.mounted) msg(context, 'Room nahi bana: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Voice Rooms')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add),
          label: const Text('Room banao'),
        ),
        body: StreamBuilder<DatabaseEvent>(
          stream: rtdb.ref('voiceRooms').onValue,
          builder: (c, s) {
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final v = s.data!.snapshot.value;
            final rooms = <MapEntry<String, Map>>[];
            if (v is Map) {
              v.forEach((k, r) {
                if (r is Map && r['meta'] is Map) {
                  rooms.add(MapEntry('$k', r));
                }
              });
            }
            rooms.sort((a, b) => ((b.value['meta']['createdAt'] ?? 0) as num)
                .compareTo((a.value['meta']['createdAt'] ?? 0) as num));
            if (rooms.isEmpty) {
              return const Center(child: Text('Abhi koi room nahi. Pehla room banao!'));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: rooms.length,
              itemBuilder: (c, i) {
                final id = rooms[i].key;
                final r = rooms[i].value;
                final meta = r['meta'] as Map;
                final seats = r['seats'] is Map ? (r['seats'] as Map).length : 0;
                final listeners = r['members'] is Map ? (r['members'] as Map).length : 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.mic)),
                    title: Text('${meta['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: UserBuilder(
                      uid: '${meta['owner']}',
                      builder: (c, p) => Text(
                          'Host: ${displayName(p)}  •  $seats/8 seats  •  $listeners online'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => VoiceRoomPage(roomId: id))),
                  ),
                );
              },
            );
          },
        ),
      );
}
