import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'onyx_chat.dart';

String dmId(String a, String b) {
  final l = [a, b]..sort();
  return '${l[0]}_${l[1]}';
}

Future<void> openDm(BuildContext context, String other) async {
  final me = myUid;
  if (other == me) return;
  final id = dmId(me, other);
  try {
    final has = await rtdb.ref('userChats/$me/$id').get();
    if (!has.exists) {
      await rtdb.ref('chatMembers/$id').set({me: true, other: true});
      await rtdb.ref('chatMeta/$id').set({'type': 'dm'});
      await rtdb.ref('userChats/$me/$id').set(ServerValue.timestamp);
      await rtdb.ref('userChats/$other/$id').set(ServerValue.timestamp);
    }
  } catch (e) {
    if (context.mounted) msg(context, 'Error: $e');
    return;
  }
  final p = await getProfile(other);
  if (!context.mounted) return;
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ChatPage(chatId: id, title: displayName(p), isGroup: false)));
}

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NewGroupPage())),
          icon: const Icon(Icons.group_add),
          label: const Text('New group'),
        ),
        body: StreamBuilder<DatabaseEvent>(
          stream: rtdb.ref('userChats/$myUid').onValue,
          builder: (c, s) {
            final v = s.data?.snapshot.value;
            final list = (v is Map ? v.entries.toList() : <MapEntry>[])
              ..sort((a, b) => ((b.value is num ? b.value : 0) as num)
                  .compareTo((a.value is num ? a.value : 0) as num));
            return ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                const OnyxTile(),
                for (final e in list) ChatTile(id: '${e.key}'),
                if (list.isEmpty && s.hasData)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'Abhi koi chat nahi.\nAdd tab se dost jodo, phir unse baat shuru karo.',
                          textAlign: TextAlign.center)),
              ],
            );
          },
        ),
      );
}

class ChatTile extends StatelessWidget {
  final String id;
  const ChatTile({super.key, required this.id});
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: rtdb.ref('chatMeta/$id').onValue,
        builder: (c, s) {
          final raw = s.data?.snapshot.value;
          final meta = raw is Map ? Map.from(raw) : {};
          final last = '${meta['last'] ?? ''}';
          if (meta['type'] == 'group') {
            final name = '${meta['name'] ?? 'Group'}';
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.group)),
              title: Text(name),
              subtitle: Text(last, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                      builder: (_) =>
                          ChatPage(chatId: id, title: name, isGroup: true))),
            );
          }
          final other = id
              .split('_')
              .firstWhere((x) => x != myUid, orElse: () => '');
          if (other.isEmpty) return const SizedBox.shrink();
          return UserBuilder(
            uid: other,
            builder: (c, p) => ListTile(
              leading: Avatar(p: p),
              title: Text(displayName(p)),
              subtitle: Text(last, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                      builder: (_) => ChatPage(
                          chatId: id, title: displayName(p), isGroup: false))),
            ),
          );
        },
      );
}

class ChatPage extends StatefulWidget {
  final String chatId;
  final String title;
  final bool isGroup;
  const ChatPage(
      {super.key,
      required this.chatId,
      required this.title,
      required this.isGroup});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final text = TextEditingController();
  List<String> members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final s = await rtdb.ref('chatMembers/${widget.chatId}').get();
      final v = s.value;
      if (v is Map) members = v.keys.map((e) => '$e').toList();
    } catch (_) {}
  }

  Future<void> _send({String? img}) async {
    final t = text.text.trim();
    if (img == null && t.isEmpty) return;
    text.clear();
    final id = widget.chatId;
    final key = rtdb.ref('messages/$id').push().key;
    final ups = <String, Object?>{
      'messages/$id/$key': {
        'from': myUid,
        'text': t,
        'img': img ?? '',
        'ts': ServerValue.timestamp,
      },
      'chatMeta/$id/last': img != null ? 'Photo' : t,
      'chatMeta/$id/lastTs': ServerValue.timestamp,
    };
    final all = {...members, myUid};
    for (final m in all) {
      ups['userChats/$m/$id'] = ServerValue.timestamp;
    }
    try {
      await rtdb.ref().update(ups);
    } catch (e) {
      if (mounted) msg(context, 'Send nahi hua: $e');
    }
  }

  Future<void> _sendPhoto() async {
    final b = await pickImageB64(maxW: 800, q: 60);
    if (b != null) await _send(img: b);
  }

  Widget _bubble(Map m) {
    final mine = m['from'] == myUid;
    final cs = Theme.of(context).colorScheme;
    final img = '${m['img'] ?? ''}';
    final t = '${m['text'] ?? ''}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isGroup && !mine)
              UserBuilder(
                  uid: '${m['from']}',
                  builder: (c, p) => Text(displayName(p),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.primary))),
            if (img.isNotEmpty)
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                      height: 200, child: B64Image(data: img, fit: BoxFit.cover))),
            if (t.isNotEmpty) Text(t),
            Align(
                alignment: Alignment.centerRight,
                child: Text(hhmm(m['ts']),
                    style: const TextStyle(fontSize: 10, color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream:
                  rtdb.ref('messages/${widget.chatId}').limitToLast(200).onValue,
              builder: (c, s) {
                if (s.hasError) return Center(child: Text('Error: ${s.error}'));
                final v = s.data?.snapshot.value;
                if (v is! Map || v.isEmpty) {
                  return const Center(child: Text('Pehla message bhejo'));
                }
                final list = v.entries.where((e) => e.value is Map).toList()
                  ..sort((a, b) => '${b.key}'.compareTo('${a.key}'));
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (c, i) => _bubble(list[i].value as Map),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(children: [
                IconButton(
                    onPressed: _sendPhoto, icon: const Icon(Icons.image_outlined)),
                Expanded(
                    child: TextField(
                  controller: text,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                      hintText: 'Message',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24))),
                )),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ]),
      );
}

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({super.key});
  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final name = TextEditingController();
  final sel = <String>{};
  bool busy = false;

  Future<void> create() async {
    final n = name.text.trim();
    if (n.isEmpty) return msg(context, 'Group ka naam likho');
    if (sel.isEmpty) return msg(context, 'Kam se kam ek dost chuno');
    setState(() => busy = true);
    try {
      final me = myUid;
      final id = rtdb.ref('chatMeta').push().key!;
      final members = {me, ...sel};
      await rtdb.ref('chatMembers/$id').set({for (final m in members) m: true});
      await rtdb.ref('chatMeta/$id').set({
        'type': 'group',
        'name': n,
        'createdBy': me,
        'last': 'Group bana',
        'lastTs': ServerValue.timestamp,
      });
      for (final m in members) {
        await rtdb.ref('userChats/$m/$id').set(ServerValue.timestamp);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ChatPage(chatId: id, title: n, isGroup: true)));
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        msg(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New group')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Group name', border: OutlineInputBorder())),
          ),
          const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('Dost chuno'))),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: rtdb.ref('friends/$myUid').onValue,
              builder: (c, s) {
                final ids = keysOf(s.data);
                if (ids.isEmpty) {
                  return const Center(
                      child: Text('Pehle Add tab se dost jodo'));
                }
                return ListView(children: [
                  for (final f in ids)
                    UserBuilder(
                      uid: f,
                      builder: (c, p) => CheckboxListTile(
                        value: sel.contains(f),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            sel.add(f);
                          } else {
                            sel.remove(f);
                          }
                        }),
                        secondary: Avatar(p: p),
                        title: Text(displayName(p)),
                        subtitle: Text('@${p['username'] ?? ''}'),
                      ),
                    ),
                ]);
              },
            ),
          ),
          SafeArea(
              child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: busy ? null : create,
                    child: Text(busy ? 'Please wait...' : 'Create group'))),
          )),
        ]),
      );
}
