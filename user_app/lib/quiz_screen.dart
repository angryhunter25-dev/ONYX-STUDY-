import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'questions_data.dart';

class _Q {
  _Q(this.q, this.options, this.answer);
  final String q;
  final List<String> options;
  final int answer;
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.subjectId, required this.subjectName});
  final String subjectId;
  final String subjectName;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final player = AudioPlayer();
  List<_Q>? qs;
  String? error;
  int idx = 0;
  int score = 0;
  int? picked;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  List<_Q> _parse(Iterable<dynamic> raw) {
    final out = <_Q>[];
    for (final m in raw) {
      if (m is! Map) continue;
      final opts = m['options'];
      final list = opts is List
          ? opts.map((e) => '$e').toList()
          : (opts is Map ? opts.values.map((e) => '$e').toList() : <String>[]);
      final ans = m['answer'];
      if (m['q'] == null || list.length < 2 || ans is! int) continue;
      out.add(_Q('${m['q']}', list, ans));
    }
    return out;
  }

  Future<void> _load() async {
    setState(() {
      qs = null;
      error = null;
      idx = 0;
      score = 0;
      picked = null;
      finished = false;
    });
    try {
      final snap = await FirebaseDatabase.instance
          .ref('questions')
          .orderByChild('subject')
          .equalTo(widget.subjectId)
          .get();
      var list = <_Q>[];
      final v = snap.value;
      if (v is Map) list = _parse(v.values);
      if (list.isEmpty && widget.subjectId == 'botany') {
        list = _parse(kSampleBotany);
      }
      list.shuffle();
      setState(() => qs = list);
    } catch (e) {
      // Offline or rules problem: fall back to samples for Botany.
      if (widget.subjectId == 'botany') {
        setState(() => qs = _parse(kSampleBotany)..shuffle());
      } else {
        setState(() => error = 'Could not load questions. Check internet.');
      }
    }
  }

  Future<void> _pick(int i) async {
    if (picked != null) return;
    final q = qs![idx];
    final ok = i == q.answer;
    setState(() {
      picked = i;
      if (ok) score++;
    });
    HapticFeedback.mediumImpact();
    try {
      await player.stop();
      await player.play(AssetSource(ok ? 'sounds/correct.wav' : 'sounds/wrong.wav'));
    } catch (_) {}
  }

  Future<void> _next() async {
    if (idx + 1 < qs!.length) {
      setState(() {
        idx++;
        picked = null;
      });
    } else {
      setState(() => finished = true);
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        try {
          await FirebaseDatabase.instance
              .ref('results/${u.uid}/${widget.subjectId}')
              .push()
              .set({
            'score': score,
            'total': qs!.length,
            'ts': ServerValue.timestamp,
          });
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectName)),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    if (qs == null) return const Center(child: CircularProgressIndicator());
    if (qs!.isEmpty) {
      return const Center(child: Text('No questions added yet.'));
    }
    if (finished) return _result(context);

    final q = qs![idx];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question ${idx + 1} of ${qs!.length}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (idx + 1) / qs!.length),
          const SizedBox(height: 24),
          Text(q.q,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (c, i) => _option(q, i),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: picked == null ? null : _next,
              child: Text(idx + 1 < qs!.length ? 'Next' : 'Finish'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(_Q q, int i) {
    Color? bg;
    Color border = Theme.of(context).colorScheme.outlineVariant;
    IconData? icon;
    if (picked != null) {
      if (i == q.answer) {
        bg = Colors.green.withOpacity(0.25);
        border = Colors.green;
        icon = Icons.check_circle;
      } else if (i == picked) {
        bg = Colors.red.withOpacity(0.25);
        border = Colors.red;
        icon = Icons.cancel;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pick(i),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 16))),
            if (icon != null)
              Icon(icon, color: i == q.answer ? Colors.green : Colors.red),
          ]),
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final total = qs!.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_outlined, size: 72),
          const SizedBox(height: 12),
          Text('$score / $total',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(score == total
              ? 'Perfect!'
              : score >= total / 2
                  ? 'Good job!'
                  : 'Keep practising!'),
          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _load, child: const Text('Try again'))),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Home'))),
        ]),
      ),
    );
  }
}
