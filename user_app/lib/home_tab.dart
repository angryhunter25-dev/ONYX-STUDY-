import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'announcements_page.dart';
import 'quiz_screen.dart';
import 'voice_rooms_page.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('subjects').onValue,
      builder: (c, s) {
        // subject id -> name
        final subjects = <String, String>{};
        final v = s.data?.snapshot.value;
        if (v is Map) {
          v.forEach((k, val) {
            if (val is Map && val['name'] != null) {
              subjects['$k'] = '${val['name']}';
            } else if (val is String) {
              subjects['$k'] = val;
            }
          });
        }
        if (subjects.isEmpty) subjects['botany'] = 'Botany';
        final items = subjects.entries.toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Row(children: [
              Expanded(
                  child: Text('Subjects',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
              AnnouncementBell(),
            ]),
            const SizedBox(height: 4),
            const Text('Pick a subject and start practising MCQs'),
            const SizedBox(height: 16),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(child: Icon(Icons.mic)),
                title: const Text('Voice Rooms',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Live 8-seat voice rooms'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VoiceRoomsPage())),
              ),
            ),
            for (final e in items)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(child: Icon(Icons.eco_outlined)),
                  title: Text(e.value,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('MCQ practice'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          QuizScreen(subjectId: e.key, subjectName: e.value))),
                ),
              ),
          ],
        );
      },
    );
  }
}
