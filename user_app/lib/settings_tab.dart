import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'common.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Future<void> feedback() async {
    final t = TextEditingController();
    final text = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('Feedback'),
              content: TextField(
                  controller: t,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      hintText: 'Write your feedback...')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(d, t.text.trim()),
                    child: const Text('Send')),
              ],
            ));
    if (text == null || text.isEmpty) return;
    try {
      await rtdb.ref('feedback').push().set(
          {'uid': myUid, 'text': text, 'ts': ServerValue.timestamp});
      if (mounted) msg(context, 'Thank you! Feedback received.');
    } catch (e) {
      if (mounted) msg(context, 'Error: $e');
    }
  }

  Future<void> contact() async {
    final ok = await launchUrl(Uri.parse('https://instagram.com/onyx_xo9'),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) msg(context, 'Could not open Instagram');
  }

  @override
  Widget build(BuildContext context) => ListView(children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('More',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text('Dark mode'),
          value: darkMode.value,
          onChanged: (v) {
            darkMode.value = v;
            saveSetting('dark', v);
            setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          subtitle: const Text('Chat and request alerts'),
          value: notificationsOn,
          onChanged: (v) {
            setState(() => notificationsOn = v);
            saveSetting('notifications', v);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.vibration),
          title: const Text('Vibration feedback'),
          value: vibrationOn,
          onChanged: (v) {
            setState(() => vibrationOn = v);
            saveSetting('vibration', v);
            if (v) HapticFeedback.mediumImpact();
          },
        ),
        ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Feedback'),
            onTap: feedback),
        ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Contact us'),
            subtitle: const Text('@onyx_xo9 on Instagram'),
            onTap: contact),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => FirebaseAuth.instance.signOut()),
      ]);
}
