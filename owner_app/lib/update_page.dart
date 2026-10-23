import 'package:flutter/material.dart';

import 'main.dart';

/// Owner: publish / clear the app update shown to all users.
/// Writes appConfig/update = {versionCode, apkUrl, notes, force}
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});
  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final code = TextEditingController();
  final url = TextEditingController();
  final notes = TextEditingController();
  bool force = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    db.ref('appConfig/update').get().then((s) {
      final v = s.value;
      if (v is Map && mounted) {
        setState(() {
          code.text = '${v['versionCode'] ?? ''}';
          url.text = '${v['apkUrl'] ?? ''}';
          notes.text = '${v['notes'] ?? ''}';
          force = v['force'] != false;
        });
      }
    }).catchError((_) {});
  }

  Future<void> publish() async {
    final n = int.tryParse(code.text.trim());
    final u = url.text.trim();
    if (n == null || n <= 0) return toast(context, 'Version code number likho');
    if (!u.startsWith('https://')) {
      return toast(context, 'APK link https:// se shuru hona chahiye');
    }
    setState(() => busy = true);
    try {
      await db.ref('appConfig/update').set({
        'versionCode': n,
        'apkUrl': u,
        'notes': notes.text.trim(),
        'force': force,
      });
      if (mounted) toast(context, 'Update publish ho gaya');
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> clear() async {
    setState(() => busy = true);
    try {
      await db.ref('appConfig/update').remove();
      if (mounted) {
        code.clear();
        url.clear();
        notes.clear();
        toast(context, 'Update band kar diya');
      }
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('App update')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                'GitHub Actions "Build User APK" chalane ke baad uski summary me '
                'Version code aur APK link milega. Woh yahan daalo. Jin users ki '
                'app ka build number isse kam hai unhe update karna padega.'),
            const SizedBox(height: 14),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Version code (build number)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'APK link (https://...)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Notes (users ko dikhenge)',
                  border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Force update'),
              subtitle: const Text(
                  'ON: update kiye bina app nahi chalega. OFF: "Later" ka option milega.'),
              value: force,
              onChanged: (v) => setState(() => force = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: busy ? null : publish,
                child: const Text('Publish update')),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: busy ? null : clear,
                child: const Text('Update band karo')),
          ],
        ),
      );
}
