import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'common.dart';
import 'profile_tab.dart';
import 'voice_config.dart';
import 'shared_browser.dart';
import 'watch_player.dart';

/// Realtime voice room: 8 seats, voice (Agora), watch together (YouTube / video
/// link, synced), room chat and invites. Everything syncs live via Firebase.
class VoiceRoomPage extends StatefulWidget {
  final String roomId;
  const VoiceRoomPage({super.key, required this.roomId});
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  late final DatabaseReference room = rtdb.ref('voiceRooms/${widget.roomId}');
  late final DatabaseReference chatRef = rtdb.ref('voiceChat/${widget.roomId}');
  final chatCtl = TextEditingController();
  RtcEngine? engine;
  bool engineReady = false;
  String? engineError;
  bool? lastPublishing; // what we last told Agora
  bool left = false;
  num serverOffset = 0;
  Map? _watch;

  @override
  void initState() {
    super.initState();
    _joinPresence();
    _initAudio();
    _loadOffset();
  }

  Future<void> _loadOffset() async {
    try {
      final e = await rtdb.ref('.info/serverTimeOffset').onValue.first;
      final v = e.snapshot.value;
      if (v is num && mounted) setState(() => serverOffset = v);
    } catch (_) {}
  }

  Future<void> _joinPresence() async {
    final m = room.child('members/$myUid');
    try {
      await m.onDisconnect().remove();
      await m.set(true);
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    final appId = await loadAgoraAppId();
    if (appId.isEmpty) {
      engineError =
          'Agora App ID set nahi hai (Owner app > App update). Seats, chat aur video chalenge, awaaz nahi.';
      if (mounted) setState(() {});
      return;
    }
    try {
      final e = createAgoraRtcEngine();
      await e.initialize(RtcEngineContext(
        appId: appId,
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
    chatCtl.dispose();
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
    if (ok == true) {
      try {
        await chatRef.remove();
      } catch (_) {}
      await room.remove();
    }
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

  // ---------- watch together ----------
  Future<void> _setLink() async {
    final ctl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Saath me video dekho'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'YouTube link ya video (.mp4) link paste karo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: const Text('Lagao')),
        ],
      ),
    );
    if (raw == null || raw.isEmpty) return;
    final p = parseWatchLink(raw);
    if (p == null) {
      if (mounted) msg(context, 'Ye link samajh nahi aaya. YouTube ya .mp4 link do.');
      return;
    }
    await room.child('watch').set({
      'k': p['k'],
      'src': p['src'],
      'playing': true,
      't': 0,
      'ts': ServerValue.timestamp,
      'by': myUid,
    });
  }

  Future<void> _clearWatch() => room.child('watch').remove();

  void _onWatchEvent(Map<String, dynamic> e) {
    final w = _watch;
    if (w == null || w['src'] == null || w['k'] == 'web') return;
    final t = (e['t'] as num?)?.toDouble() ?? 0;
    var playing = w['playing'] == true;
    switch (e['e']) {
      case 'play':
        playing = true;
        break;
      case 'pause':
        playing = false;
        break;
      case 'seek':
        playing = e['playing'] == true;
        break;
      default:
        return;
    }
    room.child('watch').set({
      'k': w['k'],
      'src': w['src'],
      'playing': playing,
      't': t,
      'ts': ServerValue.timestamp,
      'by': myUid,
    });
  }

  // ---------- chat ----------
  Future<void> _sendChat() async {
    final t = chatCtl.text.trim();
    if (t.isEmpty) return;
    chatCtl.clear();
    try {
      await chatRef.push().set({
        'uid': myUid,
        't': t.length > 500 ? t.substring(0, 500) : t,
        'ts': ServerValue.timestamp,
      });
    } catch (e) {
      if (mounted) msg(context, 'Message nahi gaya: $e');
    }
  }

  Widget _chatList() => StreamBuilder<DatabaseEvent>(
        stream: chatRef.limitToLast(80).onValue,
        builder: (c, s) {
          final items = <Map>[];
          final v = s.data?.snapshot.value;
          if (v is Map) {
            v.forEach((k, m) {
              if (m is Map) items.add(m);
            });
          }
          items.sort((a, b) =>
              ((b['ts'] ?? 0) as num).compareTo((a['ts'] ?? 0) as num));
          if (items.isEmpty) {
            return const Center(
                child: Text('Abhi koi message nahi', style: TextStyle(fontSize: 12)));
          }
          final cs = Theme.of(c).colorScheme;
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: items.length,
            itemBuilder: (c, i) {
              final m = items[i];
              final mine = m['uid'] == myUid;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  constraints:
                      BoxConstraints(maxWidth: MediaQuery.of(c).size.width * .75),
                  decoration: BoxDecoration(
                    color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!mine)
                        UserBuilder(
                          uid: '${m['uid']}',
                          builder: (c, p) => Text(displayName(p),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary)),
                        ),
                      Text('${m['t'] ?? ''}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

  // ---------- invite ----------
  Future<void> _sendInvite(String friendUid, String roomName) async {
    try {
      await rtdb.ref('voiceInvites/$friendUid/${widget.roomId}').set({
        'name': roomName,
        'from': myUid,
        'ts': ServerValue.timestamp,
      });
      if (mounted) msg(context, 'Invite bhej diya');
    } catch (e) {
      if (mounted) msg(context, 'Invite nahi gaya: $e');
    }
  }

  void _invite(String roomName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Room code copy karo'),
              subtitle: Text(widget.roomId),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.roomId));
                Navigator.pop(c);
                msg(context, 'Code copy ho gaya. Dost Voice Rooms me "Code se join" kare.');
              },
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Dost ko invite bhejo',
                      style: TextStyle(fontWeight: FontWeight.w700))),
            ),
            Flexible(
              child: StreamBuilder<DatabaseEvent>(
                stream: rtdb.ref('friends/$myUid').onValue,
                builder: (c, s) {
                  final ids = keysOf(s.data);
                  if (ids.isEmpty) {
                    return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Abhi koi friend nahi. Add tab se friend jodo.'));
                  }
                  return ListView(shrinkWrap: true, children: [
                    for (final id in ids)
                      UserBuilder(
                        uid: id,
                        builder: (c, p) => ListTile(
                          leading: Avatar(p: p, r: 20),
                          title: Text(displayName(p)),
                          trailing: FilledButton(
                              onPressed: () => _sendInvite(id, roomName),
                              child: const Text('Invite')),
                        ),
                      ),
                  ]);
                },
              ),
            ),
          ]),
        ),
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
          final watch = v['watch'] is Map ? v['watch'] as Map : null;
          _watch = watch;
          final isWeb = watch != null && watch['k'] == 'web';
          final hasVideo = watch != null && watch['src'] != null && !isWeb;

          Map? mySeat;
          int? mySeatIdx;
          for (final e in seats.entries) {
            if (e.value['uid'] == myUid) {
              mySeat = e.value;
              mySeatIdx = e.key;
            }
          }
          final canSpeak = mySeat != null &&
              mySeat['selfMuted'] != true &&
              mySeat['hostMuted'] != true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncAudio(canSpeak));

          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: Text('${meta['name']}'),
              actions: [
                IconButton(
                    tooltip: 'Invite',
                    onPressed: () => _invite('${meta['name']}'),
                    icon: const Icon(Icons.person_add_alt_1)),
                if (iAmHost)
                  IconButton(
                      tooltip: 'Room band karo',
                      onPressed: _closeRoom,
                      icon: const Icon(Icons.power_settings_new)),
              ],
            ),
            body: LayoutBuilder(
              builder: (c, box) => Column(children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: box.maxHeight * .64),
                  child: SingleChildScrollView(
                    child: Column(children: [
                      // live top bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: cs.primaryContainer,
                        child: Row(children: [
                          const Icon(Icons.circle, size: 10, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                              'LIVE  •  $online online  •  ${seats.length}/$voiceSeatCount seats',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      if (engineError != null)
                        Container(
                          width: double.infinity,
                          color: Colors.orange.withOpacity(.2),
                          padding: const EdgeInsets.all(8),
                          child: Text(engineError!, style: const TextStyle(fontSize: 12)),
                        ),
                      // shared screen (browser)
                      SharedBrowser(
                        key: const ValueKey('sb'),
                        watchRef: room.child('watch'),
                        myUid: myUid,
                      ),
                      // watch together
                      if (hasVideo)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: WatchPlayer(
                            key: const ValueKey('wp'),
                            watch: watch,
                            myUid: myUid,
                            serverOffset: serverOffset,
                            onEvent: _onWatchEvent,
                          ),
                        ),
                      Row(children: [
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _setLink,
                          icon: const Icon(Icons.ondemand_video),
                          label: Text(hasVideo ? 'Link badlo' : 'Video link'),
                        ),
                        if (hasVideo || isWeb)
                          TextButton.icon(
                            onPressed: _clearWatch,
                            icon: const Icon(Icons.close),
                            label: const Text('Hatao'),
                          ),
                      ]),
                      // seats
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 6,
                        childAspectRatio: .85,
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
                    ]),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _chatList()),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: Row(children: [
                      if (mySeat != null && mySeatIdx != null)
                        IconButton(
                          tooltip: 'Mic',
                          onPressed: mySeat['hostMuted'] == true
                              ? null
                              : () => room
                                  .child('seats/$mySeatIdx/selfMuted')
                                  .set(mySeat!['selfMuted'] != true),
                          icon: Icon(
                              canSpeak ? Icons.mic : Icons.mic_off,
                              color: canSpeak ? Colors.green : Colors.redAccent),
                        ),
                      Expanded(
                        child: TextField(
                          controller: chatCtl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendChat(),
                          decoration: const InputDecoration(
                            hintText: 'Message likho...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(onPressed: _sendChat, icon: const Icon(Icons.send)),
                    ]),
                  ),
                ),
              ]),
            ),
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
              radius: 24,
              backgroundColor: cs.surfaceContainerHighest,
              child: Icon(Icons.add, color: cs.onSurfaceVariant),
            )
          else
            UserBuilder(uid: uid, builder: (c, p) => Avatar(p: p, r: 24)),
          if (uid != null && muted)
            const Positioned(
              right: -2,
              bottom: -2,
              child: CircleAvatar(
                  radius: 9,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.mic_off, size: 11, color: Colors.white)),
            ),
          if (isHostSeat)
            const Positioned(
              left: -2,
              top: -4,
              child: Icon(Icons.workspace_premium, size: 16, color: Colors.amber),
            ),
        ]),
        const SizedBox(height: 4),
        if (uid == null)
          Text('Seat ${index + 1}',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))
        else
          UserBuilder(
            uid: uid,
            builder: (c, p) => Text(displayName(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10)),
          ),
      ]),
    );
  }
}
