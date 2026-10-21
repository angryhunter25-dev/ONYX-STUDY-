import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'wire_background.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});
  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final userC = TextEditingController(), nameC = TextEditingController();
  bool loading = false;
  String? err;
  final db = FirebaseDatabase.instance;

  Future<void> save() async {
    final name = userC.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(name)) {
      setState(() => err = '3-20 characters: a-z, 0-9, _ or .');
      return;
    }
    setState(() {
      loading = true;
      err = null;
    });
    final u = FirebaseAuth.instance.currentUser!;
    try {
      await db.ref('usernames/$name').set(u.uid); // fails if already taken
    } catch (_) {
      setState(() {
        loading = false;
        err = 'This username is already taken';
      });
      return;
    }
    if (u.email != null) {
      await db
          .ref('emails/${u.email!.toLowerCase().replaceAll('.', ',')}')
          .set(u.uid);
    }
    if (u.phoneNumber != null) {
      await db
          .ref('phones/${u.phoneNumber!.replaceAll(RegExp(r'\D'), '')}')
          .set(u.uid);
    }
    // Written last: AuthGate sees the username and opens Home.
    await db.ref('users/${u.uid}/profile').set({
      'username': name,
      'name': nameC.text.trim(),
      'bio': '',
      'photo': '',
      'createdAt': ServerValue.timestamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: WireBackground()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Choose your username',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(
                  controller: userC,
                  decoration: InputDecoration(
                      labelText: 'Username', prefixText: '@', errorText: err)),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: loading ? null : save,
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Continue')),
            ]),
          ),
        ),
      ]),
    );
  }
}
