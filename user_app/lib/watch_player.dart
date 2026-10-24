import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Parses what the user pasted. Returns {k: 'yt'|'file', src: ...} or null.
Map<String, String>? parseWatchLink(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final yt = RegExp(
          r'(?:youtu\.be/|youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/|live/|v/))([A-Za-z0-9_-]{11})')
      .firstMatch(s);
  if (yt != null) return {'k': 'yt', 'src': yt.group(1)!};
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(s)) return {'k': 'yt', 'src': s};
  if (s.startsWith('http://') || s.startsWith('https://')) {
    return {'k': 'file', 'src': s};
  }
  return null;
}

const String _html = r'''<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
#yt,#vd{position:absolute;left:0;top:0;width:100%;height:100%;border:0;display:none}
#vd{background:#000}
#ph{position:absolute;left:0;right:0;top:45%;text-align:center;color:#888;font:14px sans-serif}</style></head>
<body><div id="yt"></div><video id="vd" controls playsinline></video><div id="ph">Video nahi laga</div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
var yp=null,ready=false,pending=null,applying=false,at=null,cur='',kind='',lastT=0,lastWall=Date.now();
var vd=document.getElementById('vd'),ytd=document.getElementById('yt'),ph=document.getElementById('ph');
function post(o){try{B.postMessage(JSON.stringify(o))}catch(e){}}
function onYouTubeIframeAPIReady(){
  yp=new YT.Player('yt',{width:'100%',height:'100%',playerVars:{playsinline:1,rel:0},events:{
    onReady:function(){ready=true;if(pending){var p=pending;pending=null;cmd(p)}},
    onStateChange:function(e){if(applying||kind!='yt')return;
      if(e.data==1)post({e:'play',t:yp.getCurrentTime()});
      else if(e.data==2)post({e:'pause',t:yp.getCurrentTime()})}}});
}
function show(k){ytd.style.display=k=='yt'?'block':'none';vd.style.display=k=='file'?'block':'none';ph.style.display=k?'none':'block'}
function cmd(s){
  applying=true;clearTimeout(at);
  try{
    if(!s||s.k=='none'||!s.src){
      kind='';cur='';show('');
      try{if(ready)yp.stopVideo()}catch(e){}
      try{vd.pause();vd.removeAttribute('src');vd.load()}catch(e){}
    }else if(s.k=='yt'){
      kind='yt';show('yt');
      try{vd.pause()}catch(e){}
      if(!ready){pending=s;return}
      if(cur!=s.src){cur=s.src;yp.loadVideoById({videoId:s.src,startSeconds:s.t||0});if(!s.playing)setTimeout(function(){try{yp.pauseVideo()}catch(e){}},900)}
      else{
        if(Math.abs(yp.getCurrentTime()-s.t)>1.5)yp.seekTo(s.t,true);
        if(s.playing)yp.playVideo();else yp.pauseVideo()
      }
    }else{
      kind='file';show('file');
      try{if(ready)yp.pauseVideo()}catch(e){}
      if(cur!=s.src){cur=s.src;vd.src=s.src;vd.currentTime=s.t||0}
      else if(Math.abs(vd.currentTime-s.t)>1.5)vd.currentTime=s.t;
      if(s.playing){var pr=vd.play();if(pr&&pr.catch)pr.catch(function(){})}else vd.pause()
    }
  }catch(e){}
  at=setTimeout(function(){applying=false;lastT=0;lastWall=Date.now()},1500);
}
vd.addEventListener('play',function(){if(!applying&&kind=='file')post({e:'play',t:vd.currentTime})});
vd.addEventListener('pause',function(){if(!applying&&kind=='file')post({e:'pause',t:vd.currentTime})});
vd.addEventListener('seeked',function(){if(!applying&&kind=='file')post({e:'seek',t:vd.currentTime,playing:!vd.paused})});
setInterval(function(){
  if(applying||kind!='yt'||!ready)return;
  try{
    var t=yp.getCurrentTime(),st=yp.getPlayerState();
    var exp=lastT+(st==1?(Date.now()-lastWall)/1000:0);
    if(lastT>0&&Math.abs(t-exp)>2.5)post({e:'seek',t:t,playing:st==1});
    lastT=t;lastWall=Date.now();
  }catch(e){}
},1000);
</script></body></html>''';

/// Synced video area. [watch] is the shared state from Firebase:
/// {k: 'yt'|'file', src, playing, t, ts, by}. User actions come back through
/// [onEvent] as {e: 'play'|'pause'|'seek', t, playing?}.
class WatchPlayer extends StatefulWidget {
  final Map? watch;
  final String myUid;
  final num serverOffset; // serverTime - localTime (ms)
  final void Function(Map<String, dynamic> e) onEvent;
  const WatchPlayer({
    super.key,
    required this.watch,
    required this.myUid,
    required this.serverOffset,
    required this.onEvent,
  });
  @override
  State<WatchPlayer> createState() => _WatchPlayerState();
}

class _WatchPlayerState extends State<WatchPlayer> {
  late final WebViewController _c;
  bool _loaded = false;
  String _lastSig = '';
  String _lastSrc = '';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('B', onMessageReceived: (m) {
        try {
          final d = jsonDecode(m.message);
          if (d is Map) widget.onEvent(Map<String, dynamic>.from(d));
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        _loaded = true;
        _apply(force: true);
      }))
      ..loadHtmlString(_html, baseUrl: 'https://www.youtube.com');
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      p.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  void didUpdateWidget(covariant WatchPlayer old) {
    super.didUpdateWidget(old);
    _apply();
  }

  void _apply({bool force = false}) {
    if (!_loaded) return;
    final w = widget.watch;
    Map<String, dynamic> st;
    if (w == null || w['src'] == null) {
      st = {'k': 'none'};
    } else {
      final playing = w['playing'] == true;
      final t0 = (w['t'] as num?)?.toDouble() ?? 0;
      final ts = (w['ts'] as num?)?.toDouble() ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch + widget.serverOffset;
      final t = playing && ts > 0 ? t0 + (now - ts) / 1000 : t0;
      st = {
        'k': '${w['k']}',
        'src': '${w['src']}',
        'playing': playing,
        't': t < 0 ? 0 : t,
      };
    }
    // my own action echoes back from Firebase: do not re-apply it
    final mine = w != null && w['by'] == widget.myUid;
    final sig = '${w?['k']}|${w?['src']}|${w?['playing']}|${w?['t']}|${w?['ts']}';
    if (!force && sig == _lastSig) return;
    _lastSig = sig;
    final srcKey = '${w?['k']}|${w?['src']}';
    // my own play/pause/seek already happened in my player; a NEW video must still load
    if (mine && !force && srcKey == _lastSrc) return;
    _lastSrc = srcKey;
    _c.runJavaScript('cmd(${jsonEncode(st)})');
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _c);
}
