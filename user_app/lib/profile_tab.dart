import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'add_tab.dart';
import 'common.dart';

typedef Row2 = MapEntry<String, Map>;

class _Rows extends StatelessWidget {
  final Query q;
  final Widget Function(List<Row2>) builder;
  const _Rows({required this.q, required this.builder});
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: q.onValue,
        builder: (c, s) {
          final v = s.data?.snapshot.value;
          final out = <Row2>[];
          if (v is Map) {
            v.forEach((k, val) {
              if (val is Map) out.add(MapEntry('$k', val));
            });
          }
          return builder(out);
        },
      );
}

num _ts(Row2 e) => (e.value['ts'] as num?) ?? 0;

class ProfilePage extends StatefulWidget {
  final String uid;
  final bool tab;
  const ProfilePage({super.key, required this.uid, this.tab = false});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int tabIdx = 0;
  bool get mine => widget.uid == myUid;

  @override
  void initState() {
    super.initState();
    if (mine) _cleanStories();
  }

  /// Stories older than 24 hours are removed.
  Future<void> _cleanStories() async {
    try {
      final s = await rtdb.ref('stories/${widget.uid}').get();
      final v = s.value;
      if (v is Map) {
        final cut = DateTime.now().millisecondsSinceEpoch - 86400000;
        for (final e in v.entries) {
          final m = e.value;
          if (m is Map && m['ts'] is num && (m['ts'] as num) < cut) {
            await rtdb.ref('stories/${widget.uid}/${e.key}').remove();
          }
        }
      }
    } catch (_) {}
  }

  Future<String?> _askText(String hint) {
    final t = TextEditingController();
    return showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
              content: TextField(
                  controller: t,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: hint)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(d, t.text.trim()),
                    child: const Text('Post')),
              ],
            ));
  }

  Future<void> _addPost() async {
    final b = await pickImageB64();
    if (b == null || !mounted) return;
    final cap = await _askText('Caption (optional)');
    if (cap == null) return;
    try {
      await rtdb.ref('posts').push().set(
          {'uid': myUid, 'img': b, 'caption': cap, 'ts': ServerValue.timestamp});
      if (mounted) msg(context, 'Post ho gaya');
    } catch (e) {
      if (mounted) msg(context, 'Error: $e');
    }
  }

  Future<void> _addStory() async {
    final b = await pickImageB64();
    if (b == null) return;
    try {
      await rtdb
          .ref('stories/$myUid')
          .push()
          .set({'img': b, 'ts': ServerValue.timestamp});
      if (mounted) msg(context, 'Story lag gayi (24 ghante tak dikhegi)');
    } catch (e) {
      if (mounted) msg(context, 'Error: $e');
    }
  }

  Future<void> _addReel() async {
    final f = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (f == null || !mounted) return;
    final cap = await _askText('Caption (optional)');
    if (cap == null || !mounted) return;
    msg(context, 'Reel upload ho rahi hai...');
    try {
      final ref = FirebaseStorage.instance
          .ref('reels/$myUid/${DateTime.now().millisecondsSinceEpoch}.mp4');
      await ref.putFile(File(f.path), SettableMetadata(contentType: 'video/mp4'));
      final url = await ref.getDownloadURL();
      await rtdb.ref('reels').push().set(
          {'uid': myUid, 'url': url, 'caption': cap, 'ts': ServerValue.timestamp});
      if (mounted) msg(context, 'Reel upload ho gayi');
    } catch (e) {
      if (mounted) {
        msg(context,
            'Reel upload fail. Firebase Storage chalu karo. ($e)');
      }
    }
  }

  void _createMenu() => showModalBottomSheet(
        context: context,
        builder: (d) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Post (photo)'),
                onTap: () {
                  Navigator.pop(d);
                  _addPost();
                }),
            ListTile(
                leading: const Icon(Icons.auto_stories),
                title: const Text('Story (24 ghante)'),
                onTap: () {
                  Navigator.pop(d);
                  _addStory();
                }),
            ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Reel (video)'),
                onTap: () {
                  Navigator.pop(d);
                  _addReel();
                }),
          ]),
        ),
      );

  Widget _stat(String n, String l) => Column(children: [
        Text(n, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(l),
      ]);

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    return Scaffold(
      appBar: widget.tab ? null : AppBar(),
      body: StreamBuilder<DatabaseEvent>(
        stream: rtdb.ref('users/$uid/profile').onValue,
        builder: (c, ps) {
          final pv = ps.data?.snapshot.value;
          final p = pv is Map ? Map.from(pv) : {};
          return _Rows(
            q: rtdb.ref('stories/$uid'),
            builder: (all) {
              final cut = DateTime.now().millisecondsSinceEpoch - 86400000;
              final stories = all.where((e) => _ts(e) > cut).toList()
                ..sort((a, b) => _ts(a).compareTo(_ts(b)));
              return _Rows(
                q: rtdb.ref('posts').orderByChild('uid').equalTo(uid),
                builder: (posts) {
                  posts.sort((a, b) => _ts(b).compareTo(_ts(a)));
                  return _Rows(
                    q: rtdb.ref('reels').orderByChild('uid').equalTo(uid),
                    builder: (reels) {
                      reels.sort((a, b) => _ts(b).compareTo(_ts(a)));
                      return _body(p, stories, posts, reels);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _body(Map p, List<Row2> stories, List<Row2> posts, List<Row2> reels) {
    final hasStory = stories.isNotEmpty;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final course = '${p['course'] ?? ''}';
    final year = '${p['year'] ?? ''}';
    final bio = '${p['bio'] ?? ''}';
    final items = tabIdx == 0 ? posts : reels;
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          GestureDetector(
            onTap: () {
              if (hasStory) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            StoryViewer(uid: widget.uid, stories: stories)));
              } else if (mine) {
                _addStory();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStory
                    ? const LinearGradient(
                        colors: [Colors.purple, Colors.orange, Colors.pink])
                    : null,
                border: hasStory ? null : Border.all(color: Colors.grey),
              ),
              child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
                  child: Avatar(p: p, r: 38)),
            ),
          ),
          Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _stat('${posts.length}', 'Posts'),
            _stat('${reels.length}', 'Reels'),
          ])),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayName(p),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('@${p['username'] ?? ''}', style: const TextStyle(color: Colors.grey)),
          if (course.isNotEmpty) Text('$course  |  $year'),
          if (bio.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(bio)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: mine
            ? Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EditProfilePage(p: p))),
                        child: const Text('Edit profile'))),
                const SizedBox(width: 8),
                FilledButton.icon(
                    onPressed: _createMenu,
                    icon: const Icon(Icons.add),
                    label: const Text('Create')),
              ])
            : Align(
                alignment: Alignment.centerLeft,
                child: FriendButton(uid: widget.uid)),
      ),
      Row(children: [
        for (final i in [0, 1])
          Expanded(
            child: InkWell(
              onTap: () => setState(() => tabIdx = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            width: 2,
                            color: tabIdx == i
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent))),
                child: Icon(i == 0 ? Icons.grid_on : Icons.movie_outlined),
              ),
            ),
          ),
      ]),
      if (items.isEmpty)
        const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Abhi kuch nahi')))
      else
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final e in items)
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => tabIdx == 0
                            ? PostViewPage(id: e.key, data: e.value)
                            : ReelPlayerPage(id: e.key, data: e.value))),
                child: tabIdx == 0
                    ? B64Image(data: '${e.value['img'] ?? ''}')
                    : Container(
                        color: Colors.black87,
                        child: const Center(
                            child: Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 40))),
              ),
          ],
        ),
    ]);
  }
}

class EditProfilePage extends StatefulWidget {
  final Map p;
  const EditProfilePage({super.key, required this.p});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final name = TextEditingController(text: '${widget.p['name'] ?? ''}');
  late final bio = TextEditingController(text: '${widget.p['bio'] ?? ''}');
  late String photo = '${widget.p['photo'] ?? ''}';
  bool busy = false;

  Future<void> pick() async {
    final b = await pickImageB64(maxW: 300, q: 70);
    if (b != null) setState(() => photo = b);
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await rtdb.ref('users/$myUid/profile').update({
        'name': name.text.trim(),
        'bio': bio.text.trim(),
        'photo': photo,
      });
      invalidateProfile(myUid);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        msg(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
              child: GestureDetector(
                  onTap: pick,
                  child: Avatar(p: {...widget.p, 'photo': photo}, r: 48))),
          TextButton(onPressed: pick, child: const Text('Photo badlo')),
          const SizedBox(height: 8),
          TextField(
              controller: name,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(
              controller: bio,
              maxLines: 3,
              maxLength: 150,
              decoration: const InputDecoration(
                  labelText: 'Bio', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving...' : 'Save')),
        ]),
      );
}

class StoryViewer extends StatefulWidget {
  final String uid;
  final List<Row2> stories;
  const StoryViewer({super.key, required this.uid, required this.stories});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  int idx = 0;

  @override
  void initState() {
    super.initState();
    _markSeen(0);
  }

  void _markSeen(int i) {
    if (widget.uid == myUid || i >= widget.stories.length) return;
    rtdb
        .ref('stories/${widget.uid}/${widget.stories[i].key}/viewers/$myUid')
        .set(ServerValue.timestamp)
        .catchError((_) {});
  }

  void _showViewers() {
    final key = widget.stories[idx].key;
    showModalBottomSheet(
      context: context,
      builder: (d) => SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: rtdb.ref('stories/${widget.uid}/$key/viewers').onValue,
          builder: (c, e) {
            final v = e.data?.snapshot.value;
            final list = v is Map ? v.entries.toList() : <MapEntry>[];
            list.sort((a, b) => ((b.value is num ? b.value : 0) as num)
                .compareTo((a.value is num ? a.value : 0) as num));
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Seen by ${list.length}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              if (list.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text('Abhi kisi ne nahi dekhi')),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final x in list)
                    UserBuilder(
                      uid: '${x.key}',
                      builder: (c, p) => ListTile(
                        leading: Avatar(p: p),
                        title: Text(displayName(p)),
                        subtitle: Text('@${p['username'] ?? ''}'),
                        trailing: Text(ago(x.value)),
                      ),
                    ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stories;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          PageView.builder(
            itemCount: s.length,
            onPageChanged: (i) {
              setState(() => idx = i);
              _markSeen(i);
            },
            itemBuilder: (c, i) => Center(
                child: B64Image(data: '${s[i].value['img'] ?? ''}', fit: BoxFit.contain)),
          ),
          if (widget.uid == myUid)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: StreamBuilder<DatabaseEvent>(
                  stream: rtdb
                      .ref('stories/${widget.uid}/${s[idx].key}/viewers')
                      .onValue,
                  builder: (c, e) => TextButton.icon(
                    onPressed: _showViewers,
                    icon: const Icon(Icons.visibility, color: Colors.white),
                    label: Text('${keysOf(e.data).length} views',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            left: 4,
            right: 8,
            child: Row(children: [
              IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
              Text('${idx + 1}/${s.length}  |  ${ago(s[idx].value['ts'])}',
                  style: const TextStyle(color: Colors.white)),
              const Spacer(),
              if (widget.uid == myUid)
                IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await rtdb
                          .ref('stories/${widget.uid}/${s[idx].key}')
                          .remove();
                      if (context.mounted) Navigator.pop(context);
                    }),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PostViewPage extends StatelessWidget {
  final String id;
  final Map data;
  const PostViewPage({super.key, required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final owner = '${data['uid']}';
    return Scaffold(
      appBar: AppBar(
        title: UserBuilder(
            uid: owner, builder: (c, p) => Text(displayName(p))),
        actions: [
          if (owner == myUid)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await rtdb.ref('posts/$id').remove();
                  if (context.mounted) Navigator.pop(context);
                }),
        ],
      ),
      body: ListView(children: [
        ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: B64Image(data: '${data['img'] ?? ''}', fit: BoxFit.contain)),
        StreamBuilder<DatabaseEvent>(
          stream: rtdb.ref('posts/$id/likes').onValue,
          builder: (c, s) {
            final likes = keysOf(s.data);
            final liked = likes.contains(myUid);
            return Row(children: [
              IconButton(
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.red : null),
                onPressed: () {
                  final r = rtdb.ref('posts/$id/likes/$myUid');
                  if (liked) {
                    r.remove();
                  } else {
                    r.set(true);
                  }
                },
              ),
              Text('${likes.length} likes'),
            ]);
          },
        ),
        if ('${data['caption'] ?? ''}'.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${data['caption']}')),
      ]),
    );
  }
}

class ReelPlayerPage extends StatefulWidget {
  final String id;
  final Map data;
  const ReelPlayerPage({super.key, required this.id, required this.data});
  @override
  State<ReelPlayerPage> createState() => _ReelPlayerPageState();
}

class _ReelPlayerPageState extends State<ReelPlayerPage> {
  late final VideoPlayerController c;
  bool ready = false;
  String? err;

  @override
  void initState() {
    super.initState();
    c = VideoPlayerController.networkUrl(Uri.parse('${widget.data['url']}'));
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() => ready = true);
      c.setLooping(true);
      c.play();
    }).catchError((e) {
      if (mounted) setState(() => err = '$e');
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = '${widget.data['uid']}';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          if (owner == myUid)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await rtdb.ref('reels/${widget.id}').remove();
                  if (context.mounted) Navigator.pop(context);
                }),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Center(
            child: err != null
                ? Text('Video nahi chali: $err')
                : ready
                    ? GestureDetector(
                        onTap: () {
                          if (c.value.isPlaying) {
                            c.pause();
                          } else {
                            c.play();
                          }
                          setState(() {});
                        },
                        child: AspectRatio(
                            aspectRatio: c.value.aspectRatio,
                            child: VideoPlayer(c)))
                    : const CircularProgressIndicator(),
          ),
        ),
        if ('${widget.data['caption'] ?? ''}'.isNotEmpty)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${widget.data['caption']}',
                  style: const TextStyle(color: Colors.white))),
      ]),
    );
  }
}
