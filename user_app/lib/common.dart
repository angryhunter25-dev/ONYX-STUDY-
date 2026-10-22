import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

final rtdb = FirebaseDatabase.instance;
String get myUid => FirebaseAuth.instance.currentUser!.uid;

void msg(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String hhmm(dynamic ts) {
  if (ts is! num) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String ago(dynamic ts) {
  if (ts is! num) return '';
  final m = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(ts.toInt()))
      .inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  if (m < 1440) return '${m ~/ 60}h ago';
  return '${m ~/ 1440}d ago';
}

// ---------- profiles ----------
final Map<String, Map> _profiles = {};
void invalidateProfile(String uid) => _profiles.remove(uid);

Future<Map> getProfile(String uid) async {
  final c = _profiles[uid];
  if (c != null) return c;
  try {
    final s = await rtdb.ref('users/$uid/profile').get();
    final v = s.value;
    final m = v is Map ? Map.from(v) : {};
    _profiles[uid] = m;
    return m;
  } catch (_) {
    return {};
  }
}

String displayName(Map p) {
  final n = '${p['name'] ?? ''}'.trim();
  if (n.isNotEmpty) return n;
  final u = '${p['username'] ?? ''}';
  return u.isEmpty ? 'User' : '@$u';
}

class UserBuilder extends StatelessWidget {
  final String uid;
  final Widget Function(BuildContext, Map) builder;
  const UserBuilder({super.key, required this.uid, required this.builder});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map>(
      future: getProfile(uid), builder: (c, s) => builder(c, s.data ?? {}));
}

Uint8List? _decode(String s) {
  if (s.isEmpty) return null;
  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}

class Avatar extends StatelessWidget {
  final Map p;
  final double r;
  const Avatar({super.key, required this.p, this.r = 22});
  @override
  Widget build(BuildContext context) {
    final b = _decode('${p['photo'] ?? ''}');
    final n = displayName(p);
    return CircleAvatar(
      radius: r,
      backgroundImage: b == null ? null : MemoryImage(b),
      child: b == null
          ? Text(n.replaceAll('@', '').isEmpty
              ? '?'
              : n.replaceAll('@', '')[0].toUpperCase())
          : null,
    );
  }
}

class B64Image extends StatefulWidget {
  final String data;
  final BoxFit fit;
  const B64Image({super.key, required this.data, this.fit = BoxFit.cover});
  @override
  State<B64Image> createState() => _B64ImageState();
}

class _B64ImageState extends State<B64Image> {
  Uint8List? bytes;
  @override
  void initState() {
    super.initState();
    bytes = _decode(widget.data);
  }

  @override
  void didUpdateWidget(covariant B64Image old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) bytes = _decode(widget.data);
  }

  @override
  Widget build(BuildContext context) => bytes == null
      ? const ColoredBox(
          color: Colors.black26, child: Center(child: Icon(Icons.broken_image)))
      : Image.memory(bytes!, fit: widget.fit, gaplessPlayback: true);
}

Future<String?> pickImageB64(
    {double maxW = 900, int q = 60, ImageSource src = ImageSource.gallery}) async {
  final f = await ImagePicker()
      .pickImage(source: src, maxWidth: maxW, imageQuality: q);
  if (f == null) return null;
  return base64Encode(await f.readAsBytes());
}

// ---------- friends ----------
Future<void> sendRequest(String to) async {
  await rtdb.ref('requests/$to/$myUid').set(ServerValue.timestamp);
  await rtdb.ref('sentRequests/$myUid/$to').set(true);
}

Future<void> acceptRequest(String from) async {
  final me = myUid;
  await rtdb.ref('friends/$me/$from').set(true);
  await rtdb.ref('friends/$from/$me').set(true);
  await rtdb.ref('requests/$me/$from').remove();
  await rtdb.ref('sentRequests/$from/$me').remove();
}

Future<void> rejectRequest(String from) async {
  final me = myUid;
  await rtdb.ref('requests/$me/$from').remove();
  await rtdb.ref('sentRequests/$from/$me').remove();
}

/// Keys of a map snapshot as a list (empty if none).
List<String> keysOf(DatabaseEvent? e) {
  final v = e?.snapshot.value;
  return v is Map ? v.keys.map((k) => '$k').toList() : <String>[];
}
