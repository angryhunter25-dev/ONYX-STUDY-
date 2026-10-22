import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'common.dart';

/// Bell icon with a red dot when there is an announcement you haven't opened.
class AnnouncementBell extends StatelessWidget {
  const AnnouncementBell({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: rtdb.ref('announcements').onValue,
        builder: (c, s) {
          final v = s.data?.snapshot.value;
          num latest = 0;
          if (v is Map) {
            v.forEach((k, m) {
              if (m is Map && m['ts'] is num && (m['ts'] as num) > latest) {
                latest = m['ts'] as num;
              }
            });
          }
          return ValueListenableBuilder<int>(
            valueListenable: annSeen,
            builder: (c, seen, _) => IconButton(
              tooltip: 'Announcements',
              icon: Badge(
                  isLabelVisible: latest > seen,
                  child: const Icon(Icons.notifications_outlined)),
              onPressed: () {
                annSeen.value = latest.toInt();
                saveAnnSeen(latest.toInt());
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnnouncementsPage()));
              },
            ),
          );
        },
      );
}

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Announcements')),
        body: StreamBuilder<DatabaseEvent>(
          stream: rtdb.ref('announcements').onValue,
          builder: (c, s) {
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final v = s.data!.snapshot.value;
            final list = <Map>[];
            if (v is Map) {
              for (final m in v.values) {
                if (m is Map) list.add(m);
              }
            }
            list.sort((a, b) => ((b['ts'] as num?) ?? 0)
                .compareTo((a['ts'] as num?) ?? 0));
            if (list.isEmpty) {
              return const Center(child: Text('Abhi koi announcement nahi'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (c, i) {
                final m = list[i];
                final body = '${m['body'] ?? ''}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m['title'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          if (body.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: SelectableText(body)),
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(ago(m['ts']),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey))),
                        ]),
                  ),
                );
              },
            );
          },
        ),
      );
}
