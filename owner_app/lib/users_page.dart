import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// Owner view: who signed up, who is online / active.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String filter = 'all'; // all | online | day
  String query = '';

  static const _m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String date(int? ms) {
    if (ms == null) return '-';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_m[d.month - 1]} ${d.year}, $h:$m';
  }

  String ago(int ms) {
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    final m = diff ~/ 60000;
    if (m < 1) return 'abhi';
    if (m < 60) return '$m min pehle';
    if (m < 1440) return '${m ~/ 60} ghante pehle';
    return '${m ~/ 1440} din pehle';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('presence').onValue,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final v = s.data!.snapshot.value;
          final all = <Map>[];
          if (v is Map) {
            v.forEach((k, val) {
              if (val is Map) all.add({...val, '_uid': '$k'});
            });
          }
          int last(Map u) => (u['lastActive'] as num?)?.toInt() ?? 0;
          bool online(Map u) =>
              u['online'] == true && now - last(u) < 5 * 60 * 1000;
          bool day(Map u) => now - last(u) < 24 * 3600 * 1000;

          final nOnline = all.where(online).length;
          final nDay = all.where(day).length;

          var list = all.where((u) {
            if (filter == 'online' && !online(u)) return false;
            if (filter == 'day' && !day(u)) return false;
            if (query.isNotEmpty) {
              final t = '${u['name']} ${u['username']}'.toLowerCase();
              if (!t.contains(query.toLowerCase())) return false;
            }
            return true;
          }).toList()
            ..sort((a, b) {
              final o = (online(b) ? 1 : 0) - (online(a) ? 1 : 0);
              return o != 0 ? o : last(b).compareTo(last(a));
            });

          Widget stat(String n, String l, String f) => Expanded(
                child: InkWell(
                  onTap: () => setState(() => filter = f),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: filter == f
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text(n,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(l, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
              );

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                stat('${all.length}', 'Signed up', 'all'),
                stat('$nOnline', 'Online now', 'online'),
                stat('$nDay', 'Active 24h', 'day'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                onChanged: (t) => setState(() => query = t.trim()),
                decoration: InputDecoration(
                    hintText: 'Name ya username search',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24))),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Koi user nahi mila'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final u = list[i];
                        final name = '${u['name'] ?? ''}'.trim();
                        final un = '${u['username'] ?? ''}'.trim();
                        final title = name.isNotEmpty
                            ? name
                            : (un.isNotEmpty ? '@$un' : 'User');
                        final on = online(u);
                        return ListTile(
                          leading: Stack(children: [
                            CircleAvatar(
                                child: Text(title.characters.first
                                    .toUpperCase())),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: on ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor,
                                      width: 2),
                                ),
                              ),
                            ),
                          ]),
                          title: Text(title),
                          subtitle: Text(
                              '${un.isNotEmpty && name.isNotEmpty ? '@$un\n' : ''}'
                              'Signup: ${date((u['joinedAt'] as num?)?.toInt())}'),
                          isThreeLine: un.isNotEmpty && name.isNotEmpty,
                          trailing: Text(
                              on
                                  ? 'Online'
                                  : (last(u) == 0 ? '-' : ago(last(u))),
                              style: TextStyle(
                                  color: on ? Colors.green : Colors.grey,
                                  fontSize: 12)),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
