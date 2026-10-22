import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'common.dart';

/// Pinned "ONYX" official chat tile shown at the top of every user's Chats.
class OnyxTile extends StatelessWidget {
  const OnyxTile({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: rtdb.ref('onyxChat').limitToLast(1).onValue,
        builder: (c, s) {
          final v = s.data?.snapshot.value;
          var last = '';
          if (v is Map && v.isNotEmpty) {
            final m = v.values.first;
            if (m is Map) {
              last = '${m['text'] ?? ''}'.isNotEmpty ? '${m['text']}' : 'Photo';
            }
          }
          return ListTile(
            leading: const CircleAvatar(
                backgroundImage: AssetImage('assets/icon.png')),
            title: const Row(children: [
              Text('ONYX', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 4),
              Icon(Icons.verified, size: 16, color: Colors.blue),
            ]),
            subtitle: Text(last.isEmpty ? 'Official ONYX account' : last,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OnyxChatPage())),
          );
        },
      );
}

class OnyxChatPage extends StatelessWidget {
  const OnyxChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(
              radius: 18, backgroundImage: AssetImage('assets/icon.png')),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('ONYX', style: TextStyle(fontSize: 18)),
              SizedBox(width: 4),
              Icon(Icons.verified, size: 16, color: Colors.blue),
            ]),
            Text('Official ONYX Account',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: rtdb.ref('onyxChat').limitToLast(200).onValue,
            builder: (c, s) {
              if (s.hasError) return Center(child: Text('Error: ${s.error}'));
              final v = s.data?.snapshot.value;
              if (v is! Map || v.isEmpty) {
                return const Center(child: Text('Abhi koi message nahi'));
              }
              final list = v.entries.where((e) => e.value is Map).toList()
                ..sort((a, b) => '${b.key}'.compareTo('${a.key}'));
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (c, i) {
                  final m = list[i].value as Map;
                  final img = '${m['img'] ?? ''}';
                  final t = '${m['text'] ?? ''}';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (img.isNotEmpty)
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxHeight: 300),
                                      child: B64Image(
                                          data: img, fit: BoxFit.contain))),
                            if (t.isNotEmpty) SelectableText(t),
                            Align(
                                alignment: Alignment.centerRight,
                                child: Text(hhmm(m['ts']),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey))),
                          ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          color: cs.surfaceContainerHighest,
          child: const SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Only ONYX can send messages',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ),
      ]),
    );
  }
}
