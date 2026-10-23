import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Rooms" tab. The voice room itself is a native screen (RoomActivity) that
/// has voice, watch-together browser, room chat and invite sharing.
class RoomsTab extends StatelessWidget {
  const RoomsTab({super.key});

  static const _ch = MethodChannel('onyx/rooms');

  Future<void> _open(BuildContext context) async {
    try {
      await _ch.invokeMethod('open');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice room abhi nahi khul paaya')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget feature(IconData i, String t, String s) => ListTile(
          leading: Icon(i, color: cs.primary),
          title: Text(t),
          subtitle: Text(s),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Text('Rooms',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Dosto ke saath voice room, saath me screen dekho.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              feature(Icons.mic, 'Live voice', 'Mic se dost se baat karo'),
              feature(Icons.ondemand_video, 'Screen / video together',
                  'YouTube ya website saath dekho, sync me'),
              feature(Icons.chat_bubble_outline, 'Room chat',
                  'Dekhte dekhte chat karo'),
              feature(Icons.share, 'Invite link',
                  'Room code share karke dost ko bulao'),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.meeting_room),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Open Voice Room'),
          ),
        ),
      ],
    );
  }
}
