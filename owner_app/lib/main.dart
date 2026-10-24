import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';
import 'import_page.dart';
import 'update_page.dart';
import 'rooms_admin_page.dart';
import 'users_page.dart';

final db = FirebaseDatabase.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const OwnerApp());
}

class OwnerApp extends StatelessWidget {
  const OwnerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ONYX Owner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF7C5CFF),
            useMaterial3: true),
        home: const Gate(),
      );
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirm(BuildContext c, String msg) async =>
    (await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        title: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    )) ??
    false;

/// Login -> admin check -> Home
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) return const Busy();
          final u = s.data;
          if (u == null) return const LoginPage();
          return StreamBuilder<DatabaseEvent>(
            stream: db.ref('admins/${u.uid}').onValue,
            builder: (c, a) {
              if (a.hasError ||
                  (a.hasData && a.data!.snapshot.value != true)) {
                return NotAdmin(uid: u.uid);
              }
              if (!a.hasData) return const Busy();
              return const Home();
            },
          );
        },
      );
}

class Busy extends StatelessWidget {
  const Busy({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  String? err;

  Future<void> login() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(), password: pass.text);
    } on FirebaseAuthException catch (e) {
      err = e.message ?? e.code;
    } catch (e) {
      err = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('ONYX Owner',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password', border: OutlineInputBorder())),
              if (err != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(err!,
                        style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: loading ? null : login,
                      child: Text(loading ? 'Please wait...' : 'Sign in'))),
            ]),
          ),
        ),
      );
}

class NotAdmin extends StatelessWidget {
  final String uid;
  const NotAdmin({super.key, required this.uid});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 14),
              const Text('Yeh account admin nahi hai',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                  'Firebase Console > Realtime Database me jaake\nadmins > (neeche wala UID) = true\nbana do, phir app dobara kholo.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SelectableText(uid,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: uid));
                    toast(context, 'UID copied');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy UID')),
              TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign out')),
            ]),
          ),
        ),
      );
}

/// Live list of children at [path] as {key: map}
class Live extends StatelessWidget {
  final String path;
  final Widget Function(BuildContext, Map<String, Map>) builder;
  const Live({super.key, required this.path, required this.builder});
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: db.ref(path).onValue,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final v = s.data!.snapshot.value;
          final out = <String, Map>{};
          if (v is Map) {
            v.forEach((k, val) {
              if (val is Map) out[k.toString()] = val;
            });
          }
          return builder(c, out);
        },
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    const tabs = [SubjectsTab(), QuestionsTab(), NoticeTab(), OnyxChatTab(), ThemeTab()];
    return Scaffold(
      appBar: AppBar(title: const Text('ONYX Owner'), actions: [
        IconButton(
            tooltip: 'Rooms',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RoomsAdminPage())),
            icon: const Icon(Icons.meeting_room)),
        IconButton(
            tooltip: 'App update',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UpdatePage())),
            icon: const Icon(Icons.system_update)),
        IconButton(
            tooltip: 'Users',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UsersPage())),
            icon: const Icon(Icons.people)),
        IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout))
      ]),
      body: IndexedStack(index: i, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Subjects'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Questions'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Notices'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.palette), label: 'Theme'),
        ],
      ),
    );
  }
}

// ---------------- Subjects ----------------
class SubjectsTab extends StatelessWidget {
  const SubjectsTab({super.key});

  Future<void> add(BuildContext c) async {
    final t = TextEditingController();
    final name = await showDialog<String>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('New subject'),
        content: TextField(
            controller: t,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Botany')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, t.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    try {
      await db.ref('subjects/$id').set({'name': name});
    } catch (e) {
      if (c.mounted) toast(c, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => add(context), child: const Icon(Icons.add)),
        body: Live(
          path: 'subjects',
          builder: (c, m) => m.isEmpty
              ? const Center(child: Text('Koi subject nahi. + dabao.'))
              : ListView(
                  children: m.entries
                      .map((e) => ListTile(
                            title: Text('${e.value['name'] ?? e.key}'),
                            subtitle: Text('id: ${e.key}'),
                            trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  if (await confirm(c, 'Delete subject?')) {
                                    db.ref('subjects/${e.key}').remove();
                                  }
                                }),
                          ))
                      .toList()),
        ),
      );
}

// ---------------- Questions ----------------
class QuestionsTab extends StatefulWidget {
  const QuestionsTab({super.key});
  @override
  State<QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  String? filter;
  final Set<String> sel = {};
  bool get selecting => sel.isNotEmpty;

  Future<void> deleteSelected(BuildContext c) async {
    final n = sel.length;
    if (!await confirm(c, '$n sawal delete karne hain?')) return;
    try {
      // one single write: {questions/<id>: null, ...}
      await db.ref('questions').update({for (final k in sel) k: null});
      if (mounted) {
        setState(sel.clear);
        toast(context, '$n sawal delete ho gaye');
      }
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && selecting) setState(sel.clear);
        },
        child: Scaffold(
          floatingActionButton: selecting
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ImportPage())),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: null,
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const QuestionEditor())),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
          body: Column(children: [
            Live(
              path: 'subjects',
              builder: (c, subs) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: subs.containsKey(filter) ? filter : null,
                  hint: const Text('All subjects'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All subjects')),
                    ...subs.entries.map((e) => DropdownMenuItem<String?>(
                        value: e.key,
                        child: Text('${e.value['name'] ?? e.key}'))),
                  ],
                  onChanged: (v) => setState(() {
                    filter = v;
                    sel.clear();
                  }),
                ),
              ),
            ),
            Expanded(
              child: Live(
                path: 'questions',
                builder: (c, m) {
                  final list = m.entries
                      .where(
                          (e) => filter == null || e.value['subject'] == filter)
                      .toList();
                  if (list.isEmpty) {
                    return const Center(child: Text('Koi sawal nahi. + dabao.'));
                  }
                  final allIds = list.map((e) => e.key).toSet();
                  final allSelected =
                      allIds.isNotEmpty && sel.containsAll(allIds);
                  return Column(children: [
                    if (selecting)
                      Material(
                        color: Theme.of(c).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(children: [
                            IconButton(
                                tooltip: 'Cancel',
                                onPressed: () => setState(sel.clear),
                                icon: const Icon(Icons.close)),
                            Text('${sel.length} selected',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            TextButton(
                                onPressed: () => setState(() {
                                      if (allSelected) {
                                        sel.clear();
                                      } else {
                                        sel.addAll(allIds);
                                      }
                                    }),
                                child: Text(
                                    allSelected ? 'Unselect all' : 'Select all')),
                            IconButton(
                                tooltip: 'Delete selected',
                                onPressed: () => deleteSelected(c),
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent)),
                          ]),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Delete ke liye sawal ko dabake pakdo',
                            style: TextStyle(fontSize: 12)),
                      ),
                    Expanded(
                      child: ListView(
                          children: list
                              .map((e) => ListTile(
                                    selected: sel.contains(e.key),
                                    selectedTileColor: Theme.of(c)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.15),
                                    leading: selecting
                                        ? Checkbox(
                                            value: sel.contains(e.key),
                                            onChanged: (_) => setState(() {
                                                  sel.contains(e.key)
                                                      ? sel.remove(e.key)
                                                      : sel.add(e.key);
                                                }))
                                        : null,
                                    title: Text('${e.value['q'] ?? ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text('${e.value['subject'] ?? ''}'),
                                    onLongPress: () =>
                                        setState(() => sel.add(e.key)),
                                    onTap: () {
                                      if (selecting) {
                                        setState(() {
                                          sel.contains(e.key)
                                              ? sel.remove(e.key)
                                              : sel.add(e.key);
                                        });
                                      } else {
                                        Navigator.push(
                                            c,
                                            MaterialPageRoute(
                                                builder: (_) => QuestionEditor(
                                                    qKey: e.key,
                                                    data: e.value)));
                                      }
                                    },
                                    trailing: selecting
                                        ? null
                                        : IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            onPressed: () async {
                                              if (await confirm(
                                                  c, 'Delete question?')) {
                                                db
                                                    .ref('questions/${e.key}')
                                                    .remove();
                                              }
                                            }),
                                  ))
                              .toList()),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      );
}

class QuestionEditor extends StatefulWidget {
  final String? qKey;
  final Map? data;
  const QuestionEditor({super.key, this.qKey, this.data});
  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  final q = TextEditingController();
  final opts = List.generate(4, (_) => TextEditingController());
  int answer = 0;
  String? subject;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    if (d != null) {
      q.text = '${d['q'] ?? ''}';
      final o = d['options'];
      if (o is List) {
        for (var i = 0; i < 4 && i < o.length; i++) {
          opts[i].text = '${o[i]}';
        }
      }
      answer = (d['answer'] as num?)?.toInt() ?? 0;
      subject = d['subject']?.toString();
    }
  }

  Future<void> save() async {
    if (q.text.trim().isEmpty ||
        opts.any((o) => o.text.trim().isEmpty) ||
        subject == null) {
      toast(context, 'Subject, sawal aur chaaron options bharo');
      return;
    }
    setState(() => saving = true);
    try {
      final ref = widget.qKey == null
          ? db.ref('questions').push()
          : db.ref('questions/${widget.qKey}');
      await ref.set({
        'subject': subject,
        'q': q.text.trim(),
        'options': opts.map((o) => o.text.trim()).toList(),
        'answer': answer,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.qKey == null ? 'New question' : 'Edit question')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Live(
            path: 'subjects',
            builder: (c, subs) => subs.isEmpty
                ? const Text('Pehle Subjects tab me subject jodo.')
                : DropdownButtonFormField<String>(
                    value: subs.containsKey(subject) ? subject : null,
                    decoration: const InputDecoration(
                        labelText: 'Subject', border: OutlineInputBorder()),
                    items: subs.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value['name'] ?? e.key}')))
                        .toList(),
                    onChanged: (v) => setState(() => subject = v),
                  ),
          ),
          const SizedBox(height: 14),
          TextField(
              controller: q,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Question', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          const Text('Sahi option ke saamne wala button chuno'),
          for (var i = 0; i < 4; i++)
            Row(children: [
              Radio<int>(
                  value: i,
                  groupValue: answer,
                  onChanged: (v) => setState(() => answer = v ?? 0)),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                    controller: opts[i],
                    decoration: InputDecoration(
                        labelText: 'Option ${i + 1}',
                        border: const OutlineInputBorder())),
              )),
            ]),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : 'Save')),
        ]),
      );
}

// ---------------- Notices ----------------
class NoticeTab extends StatelessWidget {
  const NoticeTab({super.key});

  Future<void> add(BuildContext c) async {
    final t = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('New announcement'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: t, decoration: const InputDecoration(hintText: 'Title')),
          TextField(
              controller: b,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Message')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Post')),
        ],
      ),
    );
    if (ok != true || t.text.trim().isEmpty) return;
    try {
      await db.ref('announcements').push().set({
        'title': t.text.trim(),
        'body': b.text.trim(),
        'ts': ServerValue.timestamp,
      });
    } catch (e) {
      if (c.mounted) toast(c, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => add(context), child: const Icon(Icons.add)),
        body: Live(
          path: 'announcements',
          builder: (c, m) {
            final list = m.entries.toList()
              ..sort((a, b) => ((b.value['ts'] as num?) ?? 0)
                  .compareTo((a.value['ts'] as num?) ?? 0));
            if (list.isEmpty) {
              return const Center(child: Text('Koi announcement nahi. + dabao.'));
            }
            return ListView(
                children: list
                    .map((e) => ListTile(
                          title: Text('${e.value['title'] ?? ''}'),
                          subtitle: Text('${e.value['body'] ?? ''}'),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (await confirm(c, 'Delete announcement?')) {
                                  db.ref('announcements/${e.key}').remove();
                                }
                              }),
                        ))
                    .toList());
          },
        ),
      );
}

// ---------------- Theme ----------------
class ThemeTab extends StatefulWidget {
  const ThemeTab({super.key});
  @override
  State<ThemeTab> createState() => _ThemeTabState();
}

class _ThemeTabState extends State<ThemeTab> {
  final keys = ['primary', 'buttonColor', 'buttonTextColor'];
  final labels = ['App colour', 'Button colour', 'Button text colour'];
  final ctl = List.generate(3, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    db.ref('appConfig/theme').get().then((s) {
      final v = s.value;
      if (v is Map && mounted) {
        setState(() {
          for (var i = 0; i < 3; i++) {
            ctl[i].text = '${v[keys[i]] ?? ''}';
          }
        });
      }
    }).catchError((_) {});
  }

  Color? parse(String s) {
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s)) return null;
    return Color(int.parse(s.replaceFirst('#', '0xFF')));
  }

  Future<void> save() async {
    final data = <String, String>{};
    for (var i = 0; i < 3; i++) {
      final s = ctl[i].text.trim();
      if (s.isEmpty) continue;
      if (parse(s) == null) {
        toast(context, '${labels[i]}: format #RRGGBB likho (jaise #7C5CFF)');
        return;
      }
      data[keys[i]] = s;
    }
    try {
      await db.ref('appConfig/theme').set(data.isEmpty ? null : data);
      if (mounted) toast(context, 'Saved. User app me live badal jayega.');
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Colour #RRGGBB me likho. Khaali chhodo to default rahega.'),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                controller: ctl[i],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: labels[i],
                  hintText: '#7C5CFF',
                  border: const OutlineInputBorder(),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircleAvatar(
                        backgroundColor:
                            parse(ctl[i].text.trim()) ?? Colors.transparent),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: save, child: const Text('Save theme')),
        ],
      );
}

// ---------------- ONYX official chat ----------------
class OnyxChatTab extends StatefulWidget {
  const OnyxChatTab({super.key});
  @override
  State<OnyxChatTab> createState() => _OnyxChatTabState();
}

class _OnyxChatTabState extends State<OnyxChatTab> {
  final text = TextEditingController();

  Future<void> send({String? img}) async {
    final t = text.text.trim();
    if (img == null && t.isEmpty) return;
    text.clear();
    try {
      await db.ref('onyxChat').push().set(
          {'text': t, 'img': img ?? '', 'ts': ServerValue.timestamp});
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
  }

  Future<void> photo() async {
    final f = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 60);
    if (f == null) return;
    await send(img: base64Encode(await f.readAsBytes()));
  }

  String hhmm(dynamic ts) {
    if (ts is! num) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Padding(
          padding: EdgeInsets.all(10),
          child: Text('Yahan likha message sabhi users ke ONYX chat me jayega',
              style: TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: db.ref('onyxChat').limitToLast(200).onValue,
            builder: (c, s) {
              if (s.hasError) return Center(child: Text('Error: ${s.error}'));
              final v = s.data?.snapshot.value;
              if (v is! Map || v.isEmpty) {
                return const Center(child: Text('Koi message nahi'));
              }
              final list = v.entries.where((e) => e.value is Map).toList()
                ..sort((a, b) => '${b.key}'.compareTo('${a.key}'));
              return ListView.builder(
                reverse: true,
                itemCount: list.length,
                itemBuilder: (c, i) {
                  final m = list[i].value as Map;
                  final img = '${m['img'] ?? ''}';
                  final t = '${m['text'] ?? ''}';
                  return Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onLongPress: () async {
                        if (await confirm(c, 'Delete message?')) {
                          db.ref('onyxChat/${list[i].key}').remove();
                        }
                      },
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (img.isNotEmpty)
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxHeight: 260),
                                        child: Image.memory(base64Decode(img),
                                            fit: BoxFit.contain))),
                              if (t.isNotEmpty) Text(t),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(hhmm(m['ts']),
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey))),
                            ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(children: [
            IconButton(onPressed: photo, icon: const Icon(Icons.image_outlined)),
            Expanded(
                child: TextField(
              controller: text,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                  hintText: 'ONYX message',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24))),
            )),
            IconButton(onPressed: send, icon: const Icon(Icons.send)),
          ]),
        ),
      ]);
}
