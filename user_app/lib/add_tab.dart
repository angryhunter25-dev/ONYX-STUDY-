import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'chats_tab.dart';
import 'common.dart';
import 'profile_tab.dart';

class AddTab extends StatefulWidget {
  const AddTab({super.key});
  @override
  State<AddTab> createState() => _AddTabState();
}

class _AddTabState extends State<AddTab> {
  final q = TextEditingController();
  String? found;
  String? err;
  bool busy = false;

  Future<String?> _get(String path) async {
    final v = (await rtdb.ref(path).get()).value;
    return v is String ? v : null;
  }

  Future<String?> _resolve(String raw) async {
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('@') && !s.startsWith('@')) {
      return _get('emails/${s.replaceAll('.', ',')}');
    }
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10 && !RegExp(r'[a-z]').hasMatch(s)) {
      var r = await _get('phones/$digits');
      if (r == null && digits.length == 10) r = await _get('phones/91$digits');
      return r;
    }
    s = s.replaceFirst('@', '');
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(s)) return null;
    return _get('usernames/$s');
  }

  Future<void> search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      err = null;
      found = null;
    });
    try {
      final r = await _resolve(q.text);
      found = r;
      if (r == null) err = 'No user found with this name, number or email';
    } catch (e) {
      err = 'Error: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  void openProfile(String uid) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ProfilePage(uid: uid)));

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Add friend',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: 'Username, mobile number ya email',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                  onPressed: busy ? null : search, icon: const Icon(Icons.search)),
            ),
          ),
          if (busy)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator())),
          if (err != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(err!, style: const TextStyle(color: Colors.redAccent))),
          if (found != null)
            UserBuilder(
              uid: found!,
              builder: (c, p) => Card(
                margin: const EdgeInsets.only(top: 12),
                child: ListTile(
                  leading: Avatar(p: p),
                  title: Text(displayName(p)),
                  subtitle: Text('@${p['username'] ?? ''}'),
                  onTap: () => openProfile(found!),
                  trailing: FriendButton(uid: found!),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text('Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          StreamBuilder<DatabaseEvent>(
            stream: rtdb.ref('requests/$myUid').onValue,
            builder: (c, s) {
              final ids = keysOf(s.data);
              if (ids.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No requests'));
              }
              return Column(children: [
                for (final id in ids)
                  UserBuilder(
                    uid: id,
                    builder: (c, p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Avatar(p: p),
                      title: Text(displayName(p)),
                      subtitle: Text('@${p['username'] ?? ''}'),
                      onTap: () => openProfile(id),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => acceptRequest(id)),
                        IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.redAccent),
                            onPressed: () => rejectRequest(id)),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 20),
          const Text('Friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          StreamBuilder<DatabaseEvent>(
            stream: rtdb.ref('friends/$myUid').onValue,
            builder: (c, s) {
              final ids = keysOf(s.data);
              if (ids.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No friends yet'));
              }
              return Column(children: [
                for (final id in ids)
                  UserBuilder(
                    uid: id,
                    builder: (c, p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Avatar(p: p),
                      title: Text(displayName(p)),
                      subtitle: Text('@${p['username'] ?? ''}'),
                      onTap: () => openProfile(id),
                      trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () => openDm(context, id)),
                    ),
                  ),
              ]);
            },
          ),
        ],
      );
}

/// Add friend / Requested / Accept / Message button for a given user.
class FriendButton extends StatefulWidget {
  final String uid;
  const FriendButton({super.key, required this.uid});
  @override
  State<FriendButton> createState() => _FriendButtonState();
}

class _FriendButtonState extends State<FriendButton> {
  late Future<String> st = _status();

  Future<String> _status() async {
    final me = myUid;
    final u = widget.uid;
    if (u == me) return 'me';
    try {
      if ((await rtdb.ref('friends/$me/$u').get()).exists) return 'friend';
      if ((await rtdb.ref('requests/$me/$u').get()).exists) return 'incoming';
      if ((await rtdb.ref('sentRequests/$me/$u').get()).exists) return 'sent';
    } catch (_) {}
    return 'none';
  }

  Future<void> run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) msg(context, 'Error: $e');
    }
    if (mounted) setState(() => st = _status());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: st,
        builder: (c, s) {
          switch (s.data) {
            case null:
              return const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2));
            case 'me':
              return const SizedBox.shrink();
            case 'friend':
              return FilledButton.tonalIcon(
                  onPressed: () => openDm(context, widget.uid),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Message'));
            case 'incoming':
              return FilledButton(
                  onPressed: () => run(() => acceptRequest(widget.uid)),
                  child: const Text('Accept'));
            case 'sent':
              return const OutlinedButton(onPressed: null, child: Text('Requested'));
            default:
              return FilledButton(
                  onPressed: () => run(() => sendRequest(widget.uid)),
                  child: const Text('Add friend'));
          }
        },
      );
}
