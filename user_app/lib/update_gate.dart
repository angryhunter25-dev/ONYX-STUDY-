import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wraps the whole app. Reads `appConfig/update` from Realtime Database:
///   { versionCode: 105, apkUrl: "https://...apk", notes: "...", force: true }
/// If this installed build number < versionCode, the user is blocked on an
/// "Update required" screen (force=true) or asked once per launch (force=false).
/// If the node is missing, offline, or anything fails, the app just opens.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  int? current;
  String versionName = '';
  bool later = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (!mounted) return;
      setState(() {
        current = int.tryParse(p.buildNumber) ?? 0;
        versionName = p.version;
      });
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final cur = current;
    if (cur == null) return widget.child;
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('appConfig/update').onValue,
      builder: (c, s) {
        if (s.hasError || !s.hasData) return widget.child;
        final v = s.data!.snapshot.value;
        if (v is! Map) return widget.child;
        final need = int.tryParse('${v['versionCode']}') ?? 0;
        final url = '${v['apkUrl'] ?? ''}'.trim();
        final force = v['force'] != false;
        if (cur >= need || url.isEmpty) return widget.child;
        if (!force && later) return widget.child;
        return _UpdateScreen(
          url: url,
          notes: '${v['notes'] ?? ''}'.trim(),
          force: force,
          installed: '$versionName ($cur)',
          latest: need,
          onLater: () => setState(() => later = true),
        );
      },
    );
  }
}

class _UpdateScreen extends StatelessWidget {
  final String url, notes, installed;
  final int latest;
  final bool force;
  final VoidCallback onLater;
  const _UpdateScreen({
    required this.url,
    required this.notes,
    required this.installed,
    required this.latest,
    required this.force,
    required this.onLater,
  });

  Future<void> _download(BuildContext context) async {
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _err(context);
    } catch (_) {
      if (context.mounted) _err(context);
    }
  }

  void _err(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Could not open the link')));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !force,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update, size: 64, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(force ? 'Update required' : 'A new update is available',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                      'Installed: $installed  →  New build: $latest\n'
                      'Download and install the APK, then the app will open.',
                      textAlign: TextAlign.center),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(notes, textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => _download(context),
                    icon: const Icon(Icons.download),
                    label: const Text('Update now'),
                  ),
                  if (!force)
                    TextButton(onPressed: onLater, child: const Text('Later')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
