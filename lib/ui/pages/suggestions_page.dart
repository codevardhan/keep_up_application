// lib/ui/pages/suggestions_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/app_state.dart';
import '../../../router.dart';
import '../../../models/circle.dart';
import '../../../models/app_contact.dart';
import '../../../models/goal.dart';
import '../../../core/deeplink.dart';
import '../widgets/note_sheet.dart';
import '../widgets/suggestion_sheet.dart';
import '../theme/app_theme.dart';

class SuggestionsPage extends StatelessWidget {
  const SuggestionsPage({super.key});

  // ---- scoring helpers (unchanged logic) -----------------------------------
  int _cadenceBoost(Cadence c) {
    switch (c) {
      case Cadence.daily:
        return 4;
      case Cadence.weekly:
        return 3;
      case Cadence.biweekly:
        return 2;
      case Cadence.monthly:
        return 1;
    }
  }

  int _daysSince(DateTime? dt) {
    if (dt == null) return 999;
    return DateTime.now().difference(dt).inDays;
  }

  bool _goalMatch(AppContact c, Goal? active) {
    if (active == null) return false;
    final Set<String> goalCircles;
    switch (active.type) {
      case GoalType.internship:
        goalCircles = {'mentors'};
        break;
      case GoalType.family:
        goalCircles = {'family'};
        break;
      case GoalType.friends:
        goalCircles = {'friends'};
        break;
      case GoalType.wellness:
        goalCircles = {};
        break;
    }
    if (goalCircles.isEmpty) return false;
    return c.circleIds.any(goalCircles.contains);
  }

  int _circleBoostForContact(AppContact c, Map<String, Circle> circleIx) {
    var boost = 0;
    for (final id in c.circleIds) {
      final z = circleIx[id];
      if (z != null) {
        final b = _cadenceBoost(z.cadence);
        if (b > boost) boost = b;
      }
    }
    return boost;
  }

  int _score(AppContact c, Goal? goal, Map<String, Circle> circleIx) {
    final goalBonus = _goalMatch(c, goal) ? 2 : 0;
    final recency = (_daysSince(c.lastContactedAt) / 14).floor();
    final circleBoost = _circleBoostForContact(c, circleIx);
    return goalBonus + recency + circleBoost;
  }

  String _whyLabel(AppContact c, Goal? goal, Map<String, Circle> circleIx) {
    final parts = <String>[];
    if (_goalMatch(c, goal)) parts.add('Match to goal');
    final days = _daysSince(c.lastContactedAt);
    parts.add(days >= 999 ? 'No recent contact' : '${days}d since last');
    final boost = _circleBoostForContact(c, circleIx);
    if (boost > 0) parts.add('Circle boost +$boost');
    return parts.join(' • ');
  }

  String _goalLabel(GoalType t) {
    switch (t) {
      case GoalType.internship:
        return 'Find an internship';
      case GoalType.family:
        return 'Reconnect with family';
      case GoalType.friends:
        return 'Keep up with friends';
      case GoalType.wellness:
        return 'De-stress & balance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final contacts = state.contacts;
    final circleIx = {for (final c in state.circles) c.id: c};
    final goal = state.activeGoal;

    final ranked = [...contacts]
      ..sort(
        (a, b) =>
            _score(b, goal, circleIx).compareTo(_score(a, goal, circleIx)),
      );
    final top3 = ranked.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Text('Suggestions', style: AppText.h2),
        actions: [
          // Goal filter button (popup)
          PopupMenuButton<GoalType>(
            tooltip: 'Change goal',
            icon: const Icon(Icons.flag_outlined),
            onSelected: (gt) {
              final next = Goal(gt, _goalLabel(gt));
              state.setGoal(next);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: GoalType.internship,
                child: Text('Find an internship'),
              ),
              PopupMenuItem(
                value: GoalType.family,
                child: Text('Reconnect with family'),
              ),
              PopupMenuItem(
                value: GoalType.friends,
                child: Text('Keep up with friends'),
              ),
              PopupMenuItem(
                value: GoalType.wellness,
                child: Text('De-stress & balance'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBg),
        child: top3.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No suggestions yet.\nImport contacts or tag circles to get started.',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // header pills
                  if (goal != null)
                    _HeaderNote(
                      text: 'Showing suggestions for: ${goal.label}',
                      icon: Icons.info_outline,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('3 people to reach out to', style: AppText.bodySemi),
                      const Spacer(),
                      const _CapPill(text: 'Max 3/day'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // contact cards
                  ...top3.map((c) {
                    final why = _whyLabel(c, goal, circleIx);
                    final days = _daysSince(c.lastContactedAt);
                    final lastSeen = days >= 999
                        ? 'Not contacted recently'
                        : 'Last contacted: ${_ago(days)}';
                    final lastNote = state.latestNoteFor(c.id);

                    // inline circle chips for info only (no logic changes)
                    final infoChips = <Widget>[
                      if (_goalMatch(c, goal))
                        const _ReasonChip(
                          text: 'Match to goal',
                          icon: Icons.check_circle_outline,
                        ),
                      _ReasonChip(text: lastSeen, icon: Icons.schedule),
                      if (lastNote != null && lastNote.trim().isNotEmpty)
                        const _ReasonChip(
                          text: 'From notes',
                          icon: Icons.notes_outlined,
                        ),
                    ];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: AppColors.teal200,
                          width: 1.2,
                        ),
                        boxShadow: AppShadows.soft,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // top row: avatar + name + circle tag
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.neutral100,
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.neutral600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.displayName, style: AppText.h3),
                                      const SizedBox(height: 2),
                                      Text(
                                        why,
                                        style: AppText.small.copyWith(
                                          color: AppColors.neutral600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // reason chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: infoChips,
                            ),
                            if (lastNote != null &&
                                lastNote.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.purple50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  lastNote,
                                  style: AppText.small.copyWith(
                                    color: AppColors.neutral700,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // actions row
                            // actions row (responsive — no overflow)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _ActionButton.gradient(
                                  icon: Icons.message_outlined,
                                  label: 'Message',
                                  onTap: () {
                                    final number = c.phones.isNotEmpty
                                        ? c.phones.first
                                        : null;
                                    final body =
                                        'Hey ${c.displayName.split(' ').first}! Can we catch up this week?';
                                    _openMessageSheet(
                                      context,
                                      number,
                                      body,
                                      c.id,
                                    );
                                  },
                                ),
                                _ActionButton.ghost(
                                  icon: Icons.phone_outlined,
                                  label: 'Call',
                                  onTap: () {
                                    final number = c.phones.isNotEmpty
                                        ? c.phones.first
                                        : null;
                                    if (number == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('No phone on file'),
                                        ),
                                      );
                                      return;
                                    }
                                    launchCall(context, number);
                                  },
                                ),
                                _ActionButton.ghost(
                                  icon: Icons.auto_awesome,
                                  label: 'AI',
                                  onTap: () {
                                    final goalType = goal?.type;
                                    if (goalType == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Set a goal first to get AI suggestions.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final circleNames = c.circleIds
                                        .map((id) => circleIx[id]?.name ?? id)
                                        .toList();
                                    showClaudeSuggestionSheet(
                                      context: context,
                                      contact: c,
                                      goalType: goalType,
                                      circleNames: circleNames,
                                      lastNote: lastNote,
                                    );
                                  },
                                ),
                                _ActionButton.soft(
                                  icon: Icons.snooze_outlined,
                                  label: 'Snooze',
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Snoozed for now.'),
                                      ),
                                    );
                                  },
                                ),
                                // Mark button fits like the others (no Spacer!)
                                _IconOnlyButton(
                                  tooltip: 'Mark contacted today',
                                  icon: Icons.check_circle_outline,
                                  onTap: () async {
                                    await state.markContactedNow(c.id);
                                    final text = await showNoteSheet(context);
                                    if (text != null &&
                                        text.trim().isNotEmpty) {
                                      final newNote = text.trim();

                                      final existingNotes = c.notes?.trim();
                                      final combinedNotes = [
                                        if (existingNotes != null &&
                                            existingNotes.isNotEmpty)
                                          existingNotes,
                                        newNote,
                                      ].join('\n\n');

                                      final updated = c.copyWith(
                                        notes: combinedNotes,
                                      );

                                      await state.addInteraction(
                                        contactId: c.id,
                                        type: 'call',
                                        note: newNote,
                                      );

                                      await state.upsertContact(updated);
                                    }

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(content: Text('Saved')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  String _ago(int days) {
    if (days < 7) return '$days day${days == 1 ? '' : 's'} ago';
    final w = (days / 7).floor();
    return '$w week${w == 1 ? '' : 's'} ago';
  }

  void _openMessageSheet(
    BuildContext context,
    String? number,
    String body,
    String contactId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('SMS'),
              onTap: () {
                Navigator.pop(context);
                if (number == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No phone on file')),
                  );
                  return;
                }
                launchSms(context, number, body: body);
              },
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.whatsapp),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                if (number == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No phone on file')),
                  );
                  return;
                }
                launchWhatsApp(context, number, text: body);
              },
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Open composer'),
              subtitle: const Text('Use app template & log contact'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  AppRoutes.compose,
                  arguments: {'contactId': contactId},
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ----- UI bits (no new logic) -----------------------------------------------

class _HeaderNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const _HeaderNote({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.teal50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.teal600),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.body)),
        ],
      ),
    );
  }
}

class _CapPill extends StatelessWidget {
  final String text;
  const _CapPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purple100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppText.small.copyWith(
          color: AppColors.purple600,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _ReasonChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.teal100.withOpacity(.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.teal600),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppText.small.copyWith(color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}

// Compact action button that shrinks to content and plays nice inside Wrap.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  final ButtonStyle _baseStyle;
  final _Kind _kind;

  static const double _radius = 14;
  static const double _minHeight = 40;

  const _ActionButton._({
    required this.icon,
    required this.label,
    required this.onTap,
    required ButtonStyle baseStyle,
    required _Kind kind,
  }) : _baseStyle = baseStyle,
       _kind = kind;

  // Gradient CTA (uses parent gradient background)
  factory _ActionButton.gradient({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _ActionButton._(
      icon: icon,
      label: label,
      onTap: onTap,
      kind: _Kind.gradient,
      baseStyle: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, _minHeight), // content-sized width
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    );
  }

  // Subtle outlined
  factory _ActionButton.ghost({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _ActionButton._(
      icon: icon,
      label: label,
      onTap: onTap,
      kind: _Kind.ghost,
      baseStyle: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neutral700,
        side: const BorderSide(color: AppColors.neutral300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, _minHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    );
  }

  // Soft filled
  factory _ActionButton.soft({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _ActionButton._(
      icon: icon,
      label: label,
      onTap: onTap,
      kind: _Kind.soft,
      baseStyle: FilledButton.styleFrom(
        backgroundColor: AppColors.neutral100,
        foregroundColor: AppColors.neutral700,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, _minHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // child content stays compact
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label, style: AppText.bodySemi),
      ],
    );

    switch (_kind) {
      case _Kind.gradient:
        // Gradient background + clipped ripple + soft shadow
        return ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.cta, // from your theme
              boxShadow: AppShadows.medium, // from your theme
            ),
            child: TextButton(
              onPressed: onTap,
              style: _baseStyle,
              child: child,
            ),
          ),
        );

      case _Kind.ghost:
        return OutlinedButton(
          onPressed: onTap,
          style: _baseStyle,
          child: child,
        );

      case _Kind.soft:
        return FilledButton(onPressed: onTap, style: _baseStyle, child: child);
    }
  }
}

enum _Kind { gradient, ghost, soft }

class _IconOnlyButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  const _IconOnlyButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // compact, content-sized
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(36, 36),
        ),
      ),
    );
  }
}
