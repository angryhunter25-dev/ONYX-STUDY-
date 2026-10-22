import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'common.dart';
import 'profile_tab.dart';
import 'voice_config.dart';

/// Realtime voice room: 8 seats. Seats / mute / kick sync live via Firebase,
/// audio travels through Agora.
class VoiceRoomPage extends StatefulWidget {
  final String roomId;
  const VoiceRoomPage({super.key, required this.roomId});
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  late final DatabaseReference room = rtdb.ref('voiceRooms/${widget.roomId}');
  RtcEngine? engine;
  bool engineReady = false;
  String? engineError;
  bool? lastPublishing; // what we last told Agora
  bool left = false;

  @override
  void initState() {
    super.initState();
    _joinPresence();
    _initAudio();
  }

  Future<void> _joinPresence() async {
    final m = room.child('members/$myUid');
    try {
      await m.onDisconnect().remove();
      await m.set(true);
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    if (agoraAppId == 'YOUR_AGORA_APP_ID') {
      engineError = 'Agora App ID set nahi hai (voice_config.dart). Seats chalenge, awaaz nahi.';
      if (mounted) setState(() {});
      return;
    }
    try {
      final e = createAgoraRtcEngine();
      await e.initialize(RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      await e.enableAudio();
      await e.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );
      await e.joinChannel(
        token: '',
        channelId: widget.roomId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
        ),
      );
      engine = e;
      engineReady = true;
      lastPublishing = false;
    } catch (e) {
      engineError = 'Audio start nahi hua: $e';
    }
    if (mounted) setState(() {});
  }

  /// Called on every realtime update: makes the mic follow my seat state.
  void _syncAudio(bool publish) {
    final e = engine;
    if (e == null || !engineReady || publish == lastPublishing) return;
    lastPublishing = publish;
    e.updateChannelMediaOptions(ChannelMediaOptions(
      clientRoleType: publish
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
      publishMicrophoneTrack: publish,
    ));
  }

  Future<void> _leaveAll() async {
    if (left) return;
    left = true;
    try {
      final seats = (await room.child('seats').get()).value;
      if (seats is Map) {
        for (final en in seats.entries) {
          if (en.value is Map && en.value['uid'] == myUid) {
            final r = room.child('seats/${en.key}');
            await r.onDisconnect().cancel();
            await r.remove();
          }
        }
      }
      final m = room.child('members/$myUid');
      await m.onDisconnect().cancel();
      await m.remove();
    } catch (_) {}
    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
  }

  @override
  void dispose() {
    _leaveAll();
    super.dispose();
  }

  // ---------- seat actions ----------
  Future<void> _sit(int i, Map seats) async {
    if (engine != null) {
      final st = await Permission.microphone.request();
      if (!st.isGranted) {
        if (mounted) msg(context, 'Mic permission do, tabhi seat pe bol paoge');
        return;
      }
    }
    // already seated elsewhere -> free the old seat first
    for (final en in seats.entries) {
      if (en.value is Map && en.value['uid'] == myUid) {
        final old = room.child('seats/${en.key}');
        await old.onDisconnect().cancel();
        await old.remove();
      }
    }
    final ref = room.child('seats/$i');
    final res = await ref.runTransaction((cur) {
      if (cur != null) return Transaction.abort();
      return Transaction.success({'uid': myUid, 'selfMuted': false, 'hostMuted': false});
    });
    if (!res.committed) {
      if (mounted) msg(context, 'Seat ${i + 1} abhi kisi ne le li');
      return;
    }
    await ref.onDisconnect().remove();
  }

  Future<void> _standUp(int i) async {
    final r = room.child('seats/$i');
    await r.onDisconnect().cancel();
    await r.remove();
  }

  Future<void> _closeRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Room band kare?'),
        content: const Text('Sab log bahar ho jayenge.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nahi')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Haan, band karo')),
        ],
      ),
    );
    if (ok == true) await room.remove();
  }

  void _seatMenu(int i, Map? seat, Map seats, bool iAmHost) {
    final occupant = seat?['uid'] as String?;
    final mine = occupant == myUid;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (occupant == null)
            ListTile(
              leading: const Icon(Icons.event_seat),
              title: Text('Seat ${i + 1} pe baitho'),
              onTap: () {
                Navigator.pop(c);
                _sit(i, seats);
              },
            ),
          if (mine) ...[
            ListTile(
              leading: Icon(seat!['selfMuted'] == true ? Icons.mic : Icons.mic_off),
              title: Text(seat['selfMuted'] == true ? 'Mic on karo' : 'Mic mute karo'),
              onTap: () {
                Navigator.pop(c);
                room.child('seats/$i/selfMuted').set(seat['selfMuted'] != true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Seat chhodo'),
              onTap: () {
                Navigator.pop(c);
                _standUp(i);
              },
            ),
          ],
          if (occupant != null && !mine) ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile dekho'),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ProfilePage(uid: occupant)));
              },
            ),
            if (iAmHost) ...[
              ListTile(
                leading: Icon(seat!['hostMuted'] == true ? Icons.mic : Icons.mic_off),
                title: Text(seat['hostMuted'] == true ? 'Unmute karo' : 'Mute karo'),
                onTap: () {
                  Navigator.pop(c);
                  room.child('seats/$i/hostMuted').set(seat['hostMuted'] != true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.redAccent),
                title: const Text('Seat se hatao'),
                onTap: () {
                  Navigator.pop(c);
                  room.child('seats/$i').remove();
                },
              ),
            ],
          ],
        ]),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) => _leaveAll(),
      child: StreamBuilder<DatabaseEvent>(
        stream: room.onValue,
        builder: (c, s) {
          if (!s.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final v = s.data!.snapshot.value;
          if (v is! Map || v['meta'] is! Map) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
                msg(context, 'Room band ho gaya');
              }
            });
            return const Scaffold(body: SizedBox.shrink());
          }
          final meta = v['meta'] as Map;
          final seats = <int, Map>{};
          if (v['seats'] is Map) {
            (v['seats'] as Map).forEach((k, val) {
              final idx = int.tryParse('$k');
              if (idx != null && val is Map && idx >= 0 && idx < voiceSeatCount) {
                seats[idx] = val;
              }
            });
          }
          final seatsAny = {for (final e in seats.entries) e.key: e.value};
          final online = v['members'] is Map ? (v['members'] as Map).length : 0;
          final iAmHost = meta['owner'] == myUid;

          Map? mySeat;
          for (final s in seats.values) {
            if (s['uid'] == myUid) mySeat = s;
          }
          final canSpeak = mySeat != null &&
              mySeat['selfMuted'] != true &&
              mySeat['hostMuted'] != true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncAudio(canSpeak));

          return Scaffold(
            appBar: AppBar(
              title: Text('${meta['name']}'),
              actions: [
                if (iAmHost)
                  IconButton(
                      tooltip: 'Room band karo',
                      onPressed: _closeRoom,
                      icon: const Icon(Icons.power_settings_new)),
              ],
            ),
            body: Column(children: [
              // live top bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(children: [
                  const Icon(Icons.circle, size: 10, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('LIVE  •  $online online  •  ${seats.length}/$voiceSeatCount seats',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
              if (engineError != null)
                Container(
                  width: double.infinity,
                  color: Colors.orange.withOpacity(.2),
                  padding: const EdgeInsets.all(10),
                  child: Text(engineError!, style: const TextStyle(fontSize: 12)),
                ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 8,
                  childAspectRatio: .78,
                  children: [
                    for (var i = 0; i < voiceSeatCount; i++)
                      _SeatTile(
                        index: i,
                        seat: seats[i],
                        isHostSeat: seats[i]?['uid'] == meta['owner'],
                        onTap: () => _seatMenu(i, seats[i], seatsAny, iAmHost),
                      ),
                  ],
                ),
              ),
              if (mySeat != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      mySeat['hostMuted'] == true
                          ? 'Host ne tumhe mute kiya hai'
                          : (mySeat['selfMuted'] == true ? 'Mic off' : 'Mic on - tum bol sakte ho'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  final int index;
  final Map? seat;
  final bool isHostSeat;
  final VoidCallback onTap;
  const _SeatTile(
      {required this.index,
      required this.seat,
      required this.isHostSeat,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = seat?['uid'] as String?;
    final muted = seat != null && (seat!['selfMuted'] == true || seat!['hostMuted'] == true);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          if (uid == null)
            CircleAvatar(
              radius: 30,
              backgroundColor: cs.surfaceContainerHighest,
              child: Icon(Icons.add, color: cs.onSurfaceVariant),
            )
          else
            UserBuilder(uid: uid, builder: (c, p) => Avatar(p: p, r: 30)),
          if (uid != null && muted)
            const Positioned(
              right: -2,
              bottom: -2,
              child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.mic_off, size: 12, color: Colors.white)),
            ),
          if (isHostSeat)
            const Positioned(
              left: -2,
              top: -4,
              child: Icon(Icons.workspace_premium, size: 18, color: Colors.amber),
            ),
        ]),
        const SizedBox(height: 6),
        if (uid == null)
          Text('Seat ${index + 1}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
        else
          UserBuilder(
            uid: uid,
            builder: (c, p) => Text(displayName(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ),
      ]),
    );
  }
}
