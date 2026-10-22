import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class ParseResult {
  final List<Map<String, dynamic>> items;
  final int skipped;
  ParseResult(this.items, this.skipped);
}

int? _answerIndex(String raw, List<String> opts) {
  final g = raw.trim().toLowerCase();
  if (g.isEmpty) return null;
  if (g.length == 1) {
    final c = g.codeUnitAt(0);
    if (c >= 97 && c <= 101) return c - 97; // a-e
    if (c >= 49 && c <= 53) return c - 49; // 1-5
  }
  final m = RegExp(r'^\(?([a-e1-5])\)?[\.\):]?$').firstMatch(g);
  if (m != null) return _answerIndex(m.group(1)!, opts);
  for (var i = 0; i < opts.length; i++) {
    if (opts[i].trim().toLowerCase() == g) return i;
  }
  return null;
}

/// Plain text MCQs:
///   1. Question?
///   A) one   B) two   C) three   D) four   (each option on its own line)
///   Answer: B
ParseResult parseMcqText(String raw) {
  final items = <Map<String, dynamic>>[];
  var skipped = 0;
  var q = StringBuffer();
  var opts = <String>[];
  int? ans;

  void reset() {
    q = StringBuffer();
    opts = <String>[];
    ans = null;
  }

  void flush() {
    final qt = q.toString().trim();
    if (qt.isEmpty && opts.isEmpty) {
      reset();
      return;
    }
    final a = ans;
    if (qt.isNotEmpty && opts.length >= 2 && a != null && a < opts.length) {
      items.add({'q': qt, 'options': List<String>.from(opts), 'answer': a});
    } else {
      skipped++;
    }
    reset();
  }

  final ansKey =
      r'(?:answer|ans|correct\s*answer|correct|right\s*answer|उत्तर|सही\s*उत्तर)';
  final ansLetterRe =
      RegExp('^$ansKey\\s*[:\\-\\.=]?\\s*\\(?([A-Ea-e1-5])\\)?(?:\\s|\\.|\\)|\$)',
          caseSensitive: false);
  final ansTextRe =
      RegExp('^$ansKey\\s*[:\\-=]\\s*(.+)\$', caseSensitive: false);
  final optRe = RegExp(r'^\(?([A-Ea-e])[\)\.\:]\s*(.+)$');
  final numRe = RegExp(r'^(?:Q\.?\s*)?\d+\s*[\.\)\:\-]\s*', caseSensitive: false);

  for (var line in raw.split(RegExp(r'\r?\n'))) {
    line = line.trim();
    if (line.isEmpty) continue;

    if (opts.isNotEmpty) {
      final a = ansLetterRe.firstMatch(line);
      if (a != null) {
        ans = _answerIndex(a.group(1)!, opts);
        flush();
        continue;
      }
      final t = ansTextRe.firstMatch(line);
      if (t != null) {
        ans = _answerIndex(t.group(1)!, opts);
        flush();
        continue;
      }
    }
    final o = optRe.firstMatch(line);
    if (o != null && q.isNotEmpty) {
      opts.add(o.group(2)!.trim());
      continue;
    }
    if (opts.isNotEmpty) flush(); // previous question had no answer line
    if (q.isNotEmpty) {
      q.write(' ');
      q.write(line);
    } else {
      q.write(line.replaceFirst(numRe, ''));
    }
  }
  flush();
  return ParseResult(items, skipped);
}

List<String> _csvRow(String line) {
  final out = <String>[];
  var cur = StringBuffer();
  var inQ = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQ) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        cur.write(ch);
      }
    } else if (ch == '"') {
      inQ = true;
    } else if (ch == ',') {
      out.add(cur.toString().trim());
      cur = StringBuffer();
    } else {
      cur.write(ch);
    }
  }
  out.add(cur.toString().trim());
  return out;
}

/// CSV columns: question, option A, option B, option C, option D, answer
ParseResult parseCsv(String raw) {
  final items = <Map<String, dynamic>>[];
  var skipped = 0;
  var first = true;
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    final c = _csvRow(line);
    if (first) {
      first = false;
      if (c.isNotEmpty && c[0].toLowerCase().contains('question')) continue;
    }
    if (c.length < 4) {
      skipped++;
      continue;
    }
    final opts =
        c.sublist(1, c.length - 1).where((e) => e.isNotEmpty).toList();
    final a = _answerIndex(c.last, opts);
    if (c[0].isEmpty || opts.length < 2 || a == null || a >= opts.length) {
      skipped++;
    } else {
      items.add({'q': c[0], 'options': opts, 'answer': a});
    }
  }
  return ParseResult(items, skipped);
}

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final text = TextEditingController();
  String? subject;
  String? fileName;
  List<Map<String, dynamic>> items = [];
  int skipped = 0;
  bool checked = false;
  bool busy = false;

  Future<void> pick() async {
    try {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['txt', 'csv'],
          withData: true);
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final b = f.bytes;
      if (b == null) {
        if (mounted) toast(context, 'File padh nahi payi');
        return;
      }
      setState(() {
        text.text = utf8.decode(b, allowMalformed: true);
        fileName = f.name;
      });
      check();
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
  }

  void check() {
    final csv = (fileName ?? '').toLowerCase().endsWith('.csv');
    final r = csv ? parseCsv(text.text) : parseMcqText(text.text);
    setState(() {
      items = r.items;
      skipped = r.skipped;
      checked = true;
    });
  }

  Future<void> doImport() async {
    if (subject == null) return toast(context, 'Pehle subject chuno');
    if (items.isEmpty) return toast(context, 'Koi sawal nahi mila');
    setState(() => busy = true);
    try {
      final ups = <String, Object?>{};
      for (final it in items) {
        final k = db.ref('questions').push().key!;
        ups['questions/$k'] = {'subject': subject, ...it};
      }
      await db.ref().update(ups);
      if (!mounted) return;
      toast(context, '${items.length} sawal add ho gaye');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Import MCQs')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Live(
            path: 'subjects',
            builder: (c, subs) => subs.isEmpty
                ? const Text('Pehle Subjects tab me subject jodo.')
                : DropdownButtonFormField<String>(
                    value: subs.containsKey(subject) ? subject : null,
                    decoration: const InputDecoration(
                        labelText: 'Kis subject me daalna hai',
                        border: OutlineInputBorder()),
                    items: subs.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value['name'] ?? e.key}')))
                        .toList(),
                    onChanged: (v) => setState(() => subject = v),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: pick,
              icon: const Icon(Icons.upload_file),
              label: Text(fileName == null
                  ? 'File chuno (.txt ya .csv)'
                  : 'File: $fileName')),
          const SizedBox(height: 12),
          const Text('ya sawal yahan paste karo:'),
          const SizedBox(height: 6),
          TextField(
            controller: text,
            maxLines: 10,
            onChanged: (_) => setState(() => checked = false),
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    '1. Photosynthesis kahan hota hai?\nA) Root\nB) Chloroplast\nC) Stem\nD) Flower\nAnswer: B\n\n2. Agla sawal...'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(onPressed: check, child: const Text('Check karo')),
          if (checked) ...[
            const SizedBox(height: 14),
            Text('${items.length} sawal mile'
                '${skipped > 0 ? ', $skipped chhod diye (answer ya options nahi mile)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final it in items.take(5))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${it['q']}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        for (var i = 0; i < (it['options'] as List).length; i++)
                          Text(
                              '${String.fromCharCode(65 + i)}) ${(it['options'] as List)[i]}${i == it['answer'] ? '   (sahi)' : ''}',
                              style: TextStyle(
                                  color: i == it['answer']
                                      ? Colors.greenAccent
                                      : null)),
                      ]),
                ),
              ),
            if (items.length > 5) Text('...aur ${items.length - 5} sawal'),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: busy || items.isEmpty ? null : doImport,
                child: Text(busy ? 'Adding...' : '${items.length} sawal add karo')),
          ],
          const SizedBox(height: 20),
          const Text(
              'Format: har sawal ke neeche A) B) C) D) options alag-alag line me, aur last me "Answer: B". '
              'CSV me columns: question, A, B, C, D, answer.',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
}
