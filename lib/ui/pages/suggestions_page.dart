import '../../../core/app_state.dart';
import '../../../router.dart';
import '../../../models/circle.dart';
import '../../../models/app_contact.dart';
import '../../../models/goal.dart';
import '../../../core/deeplink.dart';
import '../widgets/note_sheet.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

class SuggestionsPage extends StatelessWidget {
  const SuggestionsPage({super.key});

  int _cadenceBoost(Cadence c) {
    switch (c) {
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
    if (_goalMatch(c, goal)) parts.add('Matches goal');
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Suggestions'),
            if (goal != null)
              Text(
                'Goal: ${goal.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
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
      body: top3.isEmpty
          ? const Center(
              child: Text(
                'No suggestions yet. Import contacts or tag circles.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: top3.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = top3[i];
                final circles = c.circleIds.isEmpty
                    ? '—'
                    : c.circleIds
                          .map((id) => circleIx[id]?.name ?? id)
                          .join(', ');
                final why = _whyLabel(c, goal, circleIx);
                final lastNote = state.latestNoteFor(c.id);
                final noteLine = (lastNote == null)
                    ? ''
                    : '\nLast note: $lastNote';

                // inline available circle chips (toggle add/remove)
                final List<Widget> tagChips = state.circles.map((z) {
                  final isMember = c.circleIds.contains(z.id);
                  return FilterChip(
                    label: Text(z.name),
                    selected: isMember,
                    onSelected: (selected) async {
                      if (selected) {
                        await state.addContactToCircle(c.id, z.id);
                      } else {
                        await state.removeContactFromCircle(c.id, z.id);
                      }
                      // re-rank automatically after notifyListeners()
                    },
                  );
                }).toList();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(c.displayName),
                          subtitle: Text('Circles: $circles\n$why$noteLine'),
                          isThreeLine: true,

                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Call',
                                icon: const Icon(Icons.phone_outlined),
                                onPressed: () {
                                  final number = c.phones.isNotEmpty
                                      ? c.phones.first
                                      : null;
                                  if (number == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No phone on file'),
                                      ),
                                    );
                                    return;
                                  }
                                  launchCall(context, number);
                                },
                              ),
                              IconButton(
                                tooltip: 'Message',
                                icon: const Icon(Icons.message_outlined),
                                onPressed: () {
                                  final number = c.phones.isNotEmpty
                                      ? c.phones.first
                                      : null;
                                  final body =
                                      'Hey ${c.displayName.split(' ').first}! Can we catch up this week?';
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (_) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.sms_outlined,
                                            ),
                                            title: const Text('SMS'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              if (number == null) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'No phone on file',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              launchSms(
                                                context,
                                                number,
                                                body: body,
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading: const FaIcon(
                                              FontAwesomeIcons.whatsapp,
                                            ),
                                            title: const Text('WhatsApp'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              if (number == null) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'No phone on file',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              launchWhatsApp(
                                                context,
                                                number,
                                                text: body,
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.email_outlined,
                                            ),
                                            title: const Text('Open composer'),
                                            subtitle: const Text(
                                              'Use app template & log contact',
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.compose,
                                                arguments: {'contactId': c.id},
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Mark contacted today',
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () async {
                                  await state.markContactedNow(c.id);

                                  // Prompt for an optional note
                                  final text = await showNoteSheet(context);
                                  if (text != null && text.trim().isNotEmpty) {
                                    await state.addInteraction(
                                      contactId: c.id,
                                      type: 'call',
                                      note: text,
                                    );
                                  }

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Saved${(text != null && text.trim().isNotEmpty) ? ' with note.' : '.'}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        // inline tag chips row
                        if (tagChips.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: tagChips,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
