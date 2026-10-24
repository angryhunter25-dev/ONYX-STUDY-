import 'dart:convert';
import 'dart:io';

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
  final agora = TextEditingController();
  final repo = TextEditingController();
  int? liveCode; // version users currently get
  bool force = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    db.ref('appConfig/githubRepo').get().then((s) {
      if (s.value != null && mounted) setState(() => repo.text = '${s.value}');
    }).catchError((_) {});
    db.ref('appConfig/update/versionCode').get().then((s) {
      if (s.value != null && mounted) {
        setState(() => liveCode = int.tryParse('${s.value}'));
      }
    }).catchError((_) {});
    db.ref('appConfig/agoraAppId').get().then((s) {
      if (s.value != null && mounted) setState(() => agora.text = '${s.value}');
    }).catchError((_) {});
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
      setState(() => liveCode = n);
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

  /// Reads the newest GitHub Release (made by "Build User APK") and fills
  /// version code + APK link automatically.
  Future<void> fromGithub() async {
    final r = repo.text.trim().replaceAll('https://github.com/', '');
    if (!RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(r)) {
      return toast(context, 'GitHub repo aise likho: username/repo-name');
    }
    setState(() => busy = true);
    try {
      final c = HttpClient();
      final req = await c.getUrl(
          Uri.parse('https://api.github.com/repos/$r/releases/latest'));
      req.headers.set('User-Agent', 'onyx-owner');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      c.close();
      if (res.statusCode != 200) {
        throw 'GitHub ne ${res.statusCode} diya (repo Public hai? naam sahi hai?)';
      }
      final j = jsonDecode(body) as Map;
      final tag = '${j['tag_name'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
      String link = '';
      for (final a in (j['assets'] as List? ?? [])) {
        final n = '${a['name']}';
        if (n.endsWith('.apk')) link = '${a['browser_download_url']}';
      }
      if (tag.isEmpty || link.isEmpty) throw 'Release me APK nahi mili';
      await db.ref('appConfig/githubRepo').set(r);
      if (mounted) {
        setState(() {
          code.text = tag;
          url.text = link;
        });
        toast(context, 'Version $tag mil gaya. Ab Publish dabao.');
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> saveAgora() async {
    try {
      final v = agora.text.trim();
      await db.ref('appConfig/agoraAppId').set(v.isEmpty ? null : v);
      if (mounted) toast(context, v.isEmpty ? 'Agora App ID hata diya' : 'Agora App ID save ho gaya');
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
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
            if (liveCode != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.system_update),
                  title: Text('Abhi live version: $liveCode'),
                  subtitle: const Text('Isse purani app wale users ko update dikhega'),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: repo,
              decoration: const InputDecoration(
                  labelText: 'GitHub repo (username/repo-name)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: busy ? null : fromGithub,
                icon: const Icon(Icons.cloud_download),
                label: const Text('GitHub se latest version bharo')),
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
            const Divider(height: 36),
            const Text('Voice Rooms (Agora)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'console.agora.io par free project banao ("Testing mode: App ID only") '
                'aur uska App ID yahan daalo. Awaaz tabhi chalegi.'),
            const SizedBox(height: 10),
            TextField(
              controller: agora,
              decoration: const InputDecoration(
                  labelText: 'Agora App ID', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: saveAgora, child: const Text('Save App ID')),
          ],
        ),
      );
}
