import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'profile_tab.dart';

/// ONYX accent used for speaking glow, gift banners and member badges.
const Color onyxGlow = Color(0xFF8B5CFF);

/// Stable Agora uid for a Firebase uid. Every client computes the same number,
/// so we can tell which seat is speaking without storing anything extra.
int agoraUidOf(String uid) {
  var h = 0x811C9DC5;
  for (final c in uid.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  h = h & 0x7FFFFFFF;
  return h == 0 ? 1 : h;
}

// ---------------------------------------------------------------------------
// Speaking ring (glow + ripples around the avatar while someone talks)
// ---------------------------------------------------------------------------
class SpeakingRing extends StatefulWidget {
  final bool active;
  final double radius;
  final Widget child;
  const SpeakingRing(
      {super.key,
      required this.active,
      required this.radius,
      required this.child});
  @override
  State<SpeakingRing> createState() => _SpeakingRingState();
}

class _SpeakingRingState extends State<SpeakingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(SpeakingRing old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.radius * 2;
    return SizedBox(
      width: base + 8,
      height: base + 8,
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        if (widget.active)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              return Container(
                width: base + 8 + 22 * t,
                height: base + 8 + 22 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: onyxGlow.withOpacity((1 - t) * .7), width: 2),
                ),
              );
            },
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: base + 8,
          height: base + 8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: widget.active ? onyxGlow : Colors.transparent,
                width: 2.5),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                        color: onyxGlow.withOpacity(.55),
                        blurRadius: 14,
                        spreadRadius: 1)
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Gifts
// ---------------------------------------------------------------------------
class Gift {
  final String id;
  final String emoji;
  final String name;
  final int value; // charm points the receiver gets per gift
  const Gift(this.id, this.emoji, this.name, this.value);
}

const List<Gift> kGifts = [
  Gift('rose', '🌹', 'Rose', 1),
  Gift('choc', '🍫', 'Chocolate', 2),
  Gift('cake', '🎂', 'Cake', 5),
  Gift('mic', '🎤', 'Golden Mic', 10),
  Gift('fire', '🔥', 'Fire', 15),
  Gift('gem', '💎', 'Diamond', 50),
  Gift('rocket', '🚀', 'Rocket', 100),
  Gift('crown', '👑', 'Crown', 200),
];

Gift? giftById(String? id) {
  for (final g in kGifts) {
    if (g.id == id) return g;
  }
  return null;
}

/// Full-screen gift animation: banner slides in, emoji pops up, sparkles fly.
class GiftBurst extends StatefulWidget {
  final String fromUid;
  final String toUid;
  final String emoji;
  final int qty;
  final VoidCallback onDone;
  const GiftBurst(
      {super.key,
      required this.fromUid,
      required this.toUid,
      required this.emoji,
      required this.qty,
      required this.onDone});
  @override
  State<GiftBurst> createState() => _GiftBurstState();
}

class _GiftBurstState extends State<GiftBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _banner() {
    const w = TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13);
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .92),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [onyxGlow, Color(0xFF3B82F6)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: onyxGlow.withOpacity(.5), blurRadius: 16)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: UserBuilder(
            uid: widget.fromUid,
            builder: (c, p) => Text(displayName(p),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: w),
          ),
        ),
        Text('  sent ${widget.emoji} x${widget.qty} to  ',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Flexible(
          child: UserBuilder(
            uid: widget.toUid,
            builder: (c, p) => Text(displayName(p),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: w),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final pop = Curves.elasticOut.transform((t / .3).clamp(0.0, 1.0));
          final fade = t < .75 ? 1.0 : ((1 - t) / .25).clamp(0.0, 1.0);
          final rise = Curves.easeOut.transform(t);
          final slide =
              (1 - Curves.easeOutBack.transform((t / .2).clamp(0.0, 1.0))) * -240;
          final spread = 40 + 110 * Curves.easeOut.transform((t / .6).clamp(0.0, 1.0));
          final spot = Alignment(0, .2 - .7 * rise);
          return Opacity(
            opacity: fade,
            child: Stack(children: [
              Align(
                alignment: const Alignment(0, -.82),
                child: Transform.translate(offset: Offset(slide, 0), child: _banner()),
              ),
              for (var i = 0; i < 10; i++)
                Align(
                  alignment: spot,
                  child: Transform.translate(
                    offset: Offset(math.cos(i * math.pi / 5) * spread,
                        math.sin(i * math.pi / 5) * spread),
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: const Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              Align(
                alignment: spot,
                child: Transform.scale(
                  scale: pop,
                  child: Text(widget.emoji, style: const TextStyle(fontSize: 96)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Bottom sheet: pick who to send to, how many, and which gift.
Future<void> showGiftSheet(BuildContext context,
    {required List<String> targets,
    required void Function(String to, Gift gift, int qty) onSend}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _GiftSheet(targets: targets, onSend: onSend),
  );
}

class _GiftSheet extends StatefulWidget {
  final List<String> targets;
  final void Function(String to, Gift gift, int qty) onSend;
  const _GiftSheet({required this.targets, required this.onSend});
  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  late String to = widget.targets.first;
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Send a gift',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final t in widget.targets)
                GestureDetector(
                  onTap: () => setState(() => to = t),
                  child: Container(
                    width: 66,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: to == t ? onyxGlow : Colors.transparent,
                          width: 2),
                    ),
                    child: Column(children: [
                      UserBuilder(uid: t, builder: (c, p) => Avatar(p: p, r: 18)),
                      const SizedBox(height: 4),
                      UserBuilder(
                        uid: t,
                        builder: (c, p) => Text(displayName(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final n in const [1, 10, 99])
              ChoiceChip(
                label: Text('x$n'),
                selected: qty == n,
                onSelected: (_) => setState(() => qty = n),
              ),
          ]),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: .95,
            children: [
              for (final g in kGifts)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSend(to, g, qty);
                  },
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(g.emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 2),
                    Text(g.name, style: const TextStyle(fontSize: 11)),
                  ]),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Members list
// ---------------------------------------------------------------------------
void showMembersSheet(BuildContext context, DatabaseReference room) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _MembersSheet(room: room),
  );
}

class _MembersSheet extends StatelessWidget {
  final DatabaseReference room;
  const _MembersSheet({required this.room});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .75),
        child: StreamBuilder<DatabaseEvent>(
          stream: room.onValue,
          builder: (c, s) {
            final v = s.data?.snapshot.value;
            if (v is! Map) {
              return const Padding(
                  padding: EdgeInsets.all(24), child: Text('Room closed'));
            }
            final meta = v['meta'] is Map ? v['meta'] as Map : const {};
            final owner = meta['owner'];
            final admins = v['admins'] is Map ? v['admins'] as Map : const {};
            final seated = <String>{};
            if (v['seats'] is Map) {
              (v['seats'] as Map).forEach((k, val) {
                if (val is Map && val['uid'] is String) {
                  seated.add(val['uid'] as String);
                }
              });
            }
            final ids = v['members'] is Map
                ? (v['members'] as Map).keys.map((e) => '$e').toList()
                : <String>[];
            int rank(String u) => u == owner
                ? 0
                : admins[u] == true
                    ? 1
                    : seated.contains(u)
                        ? 2
                        : 3;
            ids.sort((a, b) => rank(a).compareTo(rank(b)));
            final iAmOwner = owner == myUid;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Members  •  ${ids.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ids.length,
                  itemBuilder: (c, i) {
                    final u = ids[i];
                    final label = u == owner
                        ? 'Owner'
                        : admins[u] == true
                            ? 'Admin'
                            : seated.contains(u)
                                ? 'On seat'
                                : 'Listening';
                    return UserBuilder(
                      uid: u,
                      builder: (c, p) => ListTile(
                        leading: Avatar(p: p, r: 20),
                        title: Text(displayName(p)),
                        subtitle: Text(label),
                        onTap: () => Navigator.push(c,
                            MaterialPageRoute(builder: (_) => ProfilePage(uid: u))),
                        trailing: u == owner
                            ? const Icon(Icons.workspace_premium,
                                color: Colors.amber)
                            : (iAmOwner && u != myUid)
                                ? IconButton(
                                    tooltip: admins[u] == true
                                        ? 'Remove admin'
                                        : 'Make admin',
                                    icon: Icon(Icons.admin_panel_settings,
                                        color: admins[u] == true
                                            ? onyxGlow
                                            : Colors.grey),
                                    onPressed: () => room
                                        .child('admins/$u')
                                        .set(admins[u] == true ? null : true),
                                  )
                                : null,
                      ),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
