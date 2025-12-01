// lib/ui/pages/circles/circles_page.dart
import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/circle.dart';
import '../../../router.dart';
import '../theme/app_theme.dart';

class CirclesPage extends StatelessWidget {
  const CirclesPage({super.key});

  String _cadencePretty(Cadence c) {
    switch (c) {
      case Cadence.daily:
        return 'Daily';
      case Cadence.weekly:
        return 'Weekly';
      case Cadence.biweekly:
        return 'Every 2 weeks';
      case Cadence.monthly:
        return 'Monthly';
    }
  }

  Color _cadenceTint(Cadence c) {
    switch (c) {
      case Cadence.daily:
        return AppColors.teal200;
      case Cadence.weekly:
        return AppColors.purple200;
      case Cadence.biweekly:
        return AppColors.teal100;
      case Cadence.monthly:
        return AppColors.purple100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final circles = state.circles;

    // quick contact counts per circle (purely visual)
    final contacts = state.contacts;
    final countByCircle = <String, int>{};
    for (final c in circles) {
      countByCircle[c.id] = contacts
          .where((p) => p.circleIds.contains(c.id))
          .length;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manage circles'), centerTitle: false),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBg),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          itemCount: circles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = circles[i];
            final count = countByCircle[c.id] ?? 0;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.circleDetail,
                  arguments: {'circleId': c.id},
                );
              },
              child: DecoratedBox(
                decoration: AppDecor.card(
                  color: AppColors.white,
                ).copyWith(boxShadow: AppShadows.small),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // leading icon bubble
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.teal500, AppColors.purple500],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.group, color: Colors.white),
                      ),
                      const SizedBox(width: 12),

                      // title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // name + count pill
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c.name,
                                    style: AppText.h3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _CountPill(count: count),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // cadence chip-style subtitle
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _cadenceTint(c.cadence),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.neutral200),
                              ),
                              child: Text(
                                'Remind me: ${_cadencePretty(c.cadence)}',
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // chevron
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.neutral400,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),

      // add circle FAB
      floatingActionButton: _AddCircleFab(
        onAdded: (circle) async {
          final updated = [...state.circles, circle];
          await state.setCircles(updated);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.purple50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.neutral200),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count contact${count == 1 ? '' : 's'}',
        style: AppText.overline,
      ),
    );
  }
}

class _AddCircleFab extends StatelessWidget {
  const _AddCircleFab({required this.onAdded});
  final ValueChanged<Circle> onAdded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppGradients.cta,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          splashColor: Colors.white24,
          onPressed: () async {
            final res = await _showAddDialog(context);
            if (res != null) onAdded(res);
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add new circle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<Circle?> _showAddDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    Cadence cad = Cadence.monthly;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New circle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Family, Friends, Mentors',
              ),
            ),
            const SizedBox(height: 10),
            // use DropdownButtonFormField to get full-width & border
            DropdownButtonFormField<Cadence>(
              value: cad,
              decoration: const InputDecoration(
                labelText: 'Cadence',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              onChanged: (v) {
                cad = v ?? Cadence.monthly;
              },
              items: Cadence.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final id = nameCtrl.text.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        '_',
      );
      return Circle(id: id, name: nameCtrl.text.trim(), cadence: cad);
    }
    return null;
    // ignore: dead_code
  }
}
