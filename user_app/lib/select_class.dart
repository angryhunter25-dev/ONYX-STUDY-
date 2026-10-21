import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

const List<String> kCourses = [
  'BA', 'BCom', 'BSc', 'BBA', 'BCA', 'MA', 'MCom', 'MSc', 'Other',
];
const List<String> kYears = [
  '1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year',
];

/// Shows the "Select your Class" popup. It cannot be dismissed:
/// the student must pick a course and a year to continue.
Future<void> showSelectClassDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: _SelectClassDialog()),
  );
}

class _SelectClassDialog extends StatefulWidget {
  const _SelectClassDialog();
  @override
  State<_SelectClassDialog> createState() => _SelectClassDialogState();
}

class _SelectClassDialogState extends State<_SelectClassDialog> {
  String? course;
  String? year;
  bool saving = false;

  Future<void> _save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || course == null || year == null) return;
    setState(() => saving = true);
    try {
      await FirebaseDatabase.instance
          .ref('users/${u.uid}/profile')
          .update({'course': course, 'year': year});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check internet and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Select your Class'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Course',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kCourses)
                    ChoiceChip(
                      label: Text(c),
                      selected: course == c,
                      onSelected: (_) => setState(() => course = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Year',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final y in kYears)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => year = y),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: year == y ? cs.primary : cs.outlineVariant),
                        color: year == y
                            ? cs.primary.withOpacity(0.12)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(y)),
                          if (year == y)
                            Icon(Icons.check_circle, size: 18, color: cs.primary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: (course != null && year != null && !saving) ? _save : null,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
      ],
    );
  }
}
