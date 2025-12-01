// lib/ui/pages/circles/circle_detail_page.dart
import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/circle.dart';
import '../../../router.dart';
import '../theme/app_theme.dart';

class CircleDetailPage extends StatefulWidget {
  final String circleId;
  const CircleDetailPage({super.key, required this.circleId});

  @override
  State<CircleDetailPage> createState() => _CircleDetailPageState();
}

class _CircleDetailPageState extends State<CircleDetailPage> {
  final _searchCtl = TextEditingController();
  String _query = '';
  bool _onlyWithPhone = false;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

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
        return AppColors.teal100;
      case Cadence.weekly:
        return AppColors.purple100;
      case Cadence.biweekly:
        return AppColors.teal200;
      case Cadence.monthly:
        return AppColors.purple200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final circle = state.circles.firstWhere((c) => c.id == widget.circleId);

    final members = state.contacts
        .where((c) => c.circleIds.contains(circle.id))
        .toList();
    final nonMembers = state.contacts
        .where((c) => !c.circleIds.contains(circle.id))
        .toList();

    // Filtering for All Contacts
    final q = _query.trim().toLowerCase();
    bool matchesQuery(c) {
      if (q.isEmpty) return true;
      final name = c.displayName.toLowerCase();
      final phone = c.phones.isNotEmpty ? c.phones.first.toLowerCase() : '';
      final email = c.emails.isNotEmpty ? c.emails.first.toLowerCase() : '';
      return name.contains(q) || phone.contains(q) || email.contains(q);
    }

    bool matchesPhone(c) => !_onlyWithPhone || (c.phones.isNotEmpty);

    final filteredNonMembers = nonMembers
        .where((c) => matchesQuery(c) && matchesPhone(c))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(circle.name), centerTitle: false),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBg),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Header card with cadence controls & meta
            DecoratedBox(
              decoration: AppDecor.card(
                color: AppColors.white,
              ).copyWith(boxShadow: AppShadows.small),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title row
                    Row(
                      children: [
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
                          child: const Icon(
                            Icons.group,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(circle.name, style: AppText.h2),
                              const SizedBox(height: 4),
                              Text(
                                'Manage members & reminder cadence',
                                style: AppText.caption.copyWith(
                                  color: AppColors.neutral600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // cadence row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _cadenceTint(circle.cadence),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.neutral200),
                          ),
                          child: Text(
                            'Cadence: ${_cadencePretty(circle.cadence)}',
                            style: AppText.overline,
                          ),
                        ),
                        const Spacer(),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<Cadence>(
                            value: circle.cadence,
                            borderRadius: BorderRadius.circular(12),
                            onChanged: (v) async {
                              if (v == null) return;
                              final updated = state.circles.map((c) {
                                if (c.id == circle.id) {
                                  return c.copyWith(cadence: v);
                                }
                                return c;
                              }).toList();
                              await state.setCircles(updated);
                              setState(() {});
                            },
                            items: Cadence.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(_cadencePretty(e)),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Members section
            Text('Members', style: AppText.h3),
            const SizedBox(height: 8),
            if (members.isEmpty)
              DecoratedBox(
                decoration: AppDecor.card(color: AppColors.white),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No members yet. Add from your contacts below.',
                    style: AppText.body.copyWith(color: AppColors.neutral600),
                  ),
                ),
              )
            else
              ...members.map(
                (m) => DecoratedBox(
                  decoration: AppDecor.card(
                    color: AppColors.white,
                  ).copyWith(boxShadow: AppShadows.small),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: _Avatar(initials: _initials(m.displayName)),
                    title: Text(m.displayName, style: AppText.bodySemi),
                    subtitle: Text(
                      m.phones.isNotEmpty
                          ? m.phones.first
                          : (m.emails.isNotEmpty ? m.emails.first : ''),
                      style: AppText.caption.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          tooltip: 'View / edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.contactEdit,
                              arguments: {'contactId': m.id},
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Remove from circle',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () async {
                            await state.removeContactFromCircle(
                              m.id,
                              circle.id,
                            );
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 18),
            const Divider(height: 24),

            // All Contacts header + result count
            Row(
              children: [
                Text('All contacts', style: AppText.h3),
                const SizedBox(width: 8),
                if (_query.isNotEmpty || _onlyWithPhone)
                  Text(
                    '(${filteredNonMembers.length})',
                    style: AppText.caption.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Search & filter card
            DecoratedBox(
              decoration: AppDecor.card(color: AppColors.white),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtl,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search by name, phone, or email',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: (_query.isEmpty)
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: 'Clear',
                                onPressed: () {
                                  _searchCtl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilterChip(
                          selected: _onlyWithPhone,
                          onSelected: (v) => setState(() => _onlyWithPhone = v),
                          label: const Text('Has phone number'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (filteredNonMembers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No contacts match your filter.',
                  style: AppText.body.copyWith(color: AppColors.neutral600),
                ),
              )
            else
              ...filteredNonMembers.map(
                (c) => DecoratedBox(
                  decoration: AppDecor.card(
                    color: AppColors.white,
                  ).copyWith(boxShadow: AppShadows.small),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: _Avatar(initials: _initials(c.displayName)),
                    title: Text(c.displayName, style: AppText.bodySemi),
                    subtitle: Text(
                      c.phones.isNotEmpty
                          ? c.phones.first
                          : (c.emails.isNotEmpty ? c.emails.first : ''),
                      style: AppText.caption.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          tooltip: 'View / edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.contactEdit,
                              arguments: {'contactId': c.id},
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Add to circle',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () async {
                            await state.addContactToCircle(c.id, circle.id);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.take(2).toString();
    return '${parts.first.characters.take(1)}${parts.last.characters.take(1)}'
        .toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.teal500, AppColors.purple500],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppText.bodySemi.copyWith(color: Colors.white),
      ),
    );
  }
}
