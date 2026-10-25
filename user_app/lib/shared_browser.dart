import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Full browser (Google / YouTube / any site). The page address is shared with
/// everyone in the room through voiceRooms/<id>/watch {k:'web', src, by, ts}.
class SharedBrowser extends StatefulWidget {
  final DatabaseReference watchRef;
  final String myUid;
  const SharedBrowser({super.key, required this.watchRef, required this.myUid});
  @override
  State<SharedBrowser> createState() => _SharedBrowserState();
}

class _SharedBrowserState extends State<SharedBrowser> {
  late final WebViewController _c;
  final urlCtl = TextEditingController();
  StreamSubscription<DatabaseEvent>? _sub;
  bool sync = true;
  int progress = 0;
  bool big = false;
  String _cur = '';
  String _lastWritten = '';

  static String normalize(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'https://www.google.com';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (!s.contains(' ') && s.contains('.')) return 'https://$s';
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(s)}';
  }

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => progress = p);
        },
        onUrlChange: (ch) => _onLocalUrl(ch.url),
        onPageFinished: (u) => _onLocalUrl(u),
      ));
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      p.setMediaPlaybackRequiresUserGesture(false);
    }
    _start();
  }

  Future<void> _start() async {
    String first = 'https://www.google.com';
    try {
      final s = await widget.watchRef.get();
      final v = s.value;
      if (v is Map && v['k'] == 'web' && v['src'] != null) first = '${v['src']}';
    } catch (_) {}
    _cur = first;
    urlCtl.text = first;
    _c.loadRequest(Uri.parse(first));
    _sub = widget.watchRef.onValue.listen((e) {
      final v = e.snapshot.value;
      if (!sync || v is! Map || v['k'] != 'web' || v['by'] == widget.myUid) return;
      final src = '${v['src']}';
      if (src.isEmpty || src == _cur) return;
      _cur = src;
      _lastWritten = src;
      urlCtl.text = src;
      _c.loadRequest(Uri.parse(src));
    });
  }

  void _onLocalUrl(String? u) {
    if (u == null || u.isEmpty || u == 'about:blank') return;
    if (mounted) urlCtl.text = u;
    if (u == _cur || u == _lastWritten) return;
    _cur = u;
    if (!sync) return;
    _lastWritten = u;
    widget.watchRef.set({
      'k': 'web',
      'src': u,
      'playing': true,
      't': 0,
      'ts': ServerValue.timestamp,
      'by': widget.myUid,
    });
  }

  void _go(String raw) {
    final u = normalize(raw);
    FocusScope.of(context).unfocus();
    _c.loadRequest(Uri.parse(u));
  }

  @override
  void dispose() {
    _sub?.cancel();
    urlCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: big ? 440 : 280,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(children: [
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  if (await _c.canGoBack()) _c.goBack();
                },
                icon: const Icon(Icons.arrow_back, size: 20)),
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: urlCtl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: _go,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search Google / YouTube or enter a link',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _c.reload(),
                icon: const Icon(Icons.refresh, size: 20)),
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => big = !big),
                icon: Icon(big ? Icons.fullscreen_exit : Icons.fullscreen, size: 22)),
          ]),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _chip('Google', () => _go('https://www.google.com')),
              _chip('YouTube', () => _go('https://m.youtube.com')),
              const SizedBox(width: 8),
              Row(children: [
                const Text('Sync with everyone', style: TextStyle(fontSize: 12)),
                Switch(value: sync, onChanged: (v) => setState(() => sync = v)),
              ]),
            ],
          ),
        ),
        if (progress < 100) LinearProgressIndicator(value: progress / 100, minHeight: 2),
        Expanded(child: WebViewWidget(
          controller: _c,
          gestureRecognizers: {
            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
          },
        )),
      ]),
    );
  }

  Widget _chip(String t, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ActionChip(label: Text(t), onPressed: f),
      );
}
