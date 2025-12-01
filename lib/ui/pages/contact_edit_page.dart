import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/app_contact.dart';
import '../../../models/circle.dart';

import '../widgets/note_sheet.dart';
import '../../../core/deeplink.dart';

// Lightweight header for modal sheets with a drag handle + title.
class _SheetHeader extends StatelessWidget {
  final String title;
  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        // drag handle
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: textStyle),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
      ],
    );
  }
}

class ContactEditPage extends StatefulWidget {
  final String contactId;
  const ContactEditPage({super.key, required this.contactId});

  @override
  State<ContactEditPage> createState() => _ContactEditPageState();
}

class _ContactEditPageState extends State<ContactEditPage> {
  late AppContact contact;

  // Controllers
  final companyCtl = TextEditingController();
  final titleCtl = TextEditingController();
  final locationCtl = TextEditingController();
  final linkedinCtl = TextEditingController();
  final notesCtl = TextEditingController();
  final tagsCtl = TextEditingController();

  String? tz;
  ContactChannel preferred = ContactChannel.none;
  Set<int> availDays = {};
  int? availStart;
  int? availEnd;
  Cadence? cadenceOverride;
  late List<String> circleIds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = InheritedAppState.of(context);
    contact = state.contacts.firstWhere((c) => c.id == widget.contactId);

    // Populate form fields
    companyCtl.text = contact.company ?? '';
    titleCtl.text = contact.title ?? '';
    locationCtl.text = contact.location ?? '';
    linkedinCtl.text = contact.linkedin ?? '';
    notesCtl.text = contact.notes ?? '';
    tagsCtl.text = contact.tags.join(', ');

    tz = contact.timeZone;
    preferred = contact.preferred;
    availDays = {...contact.availDays};
    availStart = contact.availStart;
    availEnd = contact.availEnd;
    cadenceOverride = contact.cadenceOverride;
    circleIds = [...contact.circleIds];
  }

  @override
  void dispose() {
    companyCtl.dispose();
    titleCtl.dispose();
    locationCtl.dispose();
    linkedinCtl.dispose();
    notesCtl.dispose();
    tagsCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = InheritedAppState.of(context);
    final tags = tagsCtl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final updated = contact.copyWith(
      company: companyCtl.text.trim().isEmpty ? null : companyCtl.text.trim(),
      title: titleCtl.text.trim().isEmpty ? null : titleCtl.text.trim(),
      location: locationCtl.text.trim().isEmpty
          ? null
          : locationCtl.text.trim(),
      linkedin: linkedinCtl.text.trim().isEmpty
          ? null
          : linkedinCtl.text.trim(),
      notes: notesCtl.text.trim().isNotEmpty ? notesCtl.text.trim() : null,
      tags: tags,
      timeZone: tz,
      preferred: preferred,
      availDays: availDays,
      availStart: availStart,
      availEnd: availEnd,
      cadenceOverride: cadenceOverride,
      circleIds: circleIds,
    );

    await state.upsertContact(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved')));
    Navigator.pop(context);
  }

  Future<void> _markContacted() async {
    final state = InheritedAppState.of(context);
    await state.markContactedNow(contact.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marked as contacted today')));
    setState(() {});
  }

  String _lastContactedLabel() {
    final t = contact.lastContactedAt;
    if (t == null) return 'Not yet';
    final d = DateTime.now().difference(t).inDays;
    if (d == 0) return 'Today';
    if (d == 1) return '1 day ago';
    return '$d days ago';
  }

  String _cadenceLabel(AppState state) {
    if (cadenceOverride != null) return _cadenceToLabel(cadenceOverride!);
    // Fall back to strictest from circles
    final days = _strictestCadenceDays(state, contact.circleIds);
    if (days == null) return 'No cadence';
    return _daysToCadenceLabel(days);
  }

  int? _strictestCadenceDays(AppState state, List<String> ids) {
    final list = <int>[];
    for (final id in ids) {
      final c = state.circles.where((e) => e.id == id);
      if (c.isEmpty) continue;
      list.add(_cadenceToDays(c.first.cadence));
    }
    if (list.isEmpty) return null;
    list.sort();
    return list.first;
  }

  String _cadenceToLabel(Cadence c) {
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

  int _cadenceToDays(Cadence c) {
    switch (c) {
      case Cadence.daily:
        return 1;
      case Cadence.weekly:
        return 7;
      case Cadence.biweekly:
        return 14;
      case Cadence.monthly:
        return 30;
    }
  }

  String _daysToCadenceLabel(int d) {
    if (d <= 1) return 'Daily';
    if (d <= 7) return 'Weekly';
    if (d <= 14) return 'Every 2 weeks';
    return 'Monthly';
    // simple map is sufficient for our enum set
  }

  Future<void> _pickCadenceOverride() async {
    final picked = await showModalBottomSheet<Cadence?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHeader(title: 'Reminder frequency'),
              const SizedBox(height: 8),
              RadioListTile<Cadence?>(
                value: null,
                groupValue: cadenceOverride,
                title: const Text('Use circle cadence (default)'),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
              ...Cadence.values.map(
                (c) => RadioListTile<Cadence?>(
                  value: c,
                  groupValue: cadenceOverride,
                  title: Text(_cadenceToLabel(c)),
                  onChanged: (v) => Navigator.pop(ctx, v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null || picked == null) {
      setState(() => cadenceOverride = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final circleNames = state.circles
        .where((z) => contact.circleIds.contains(z.id))
        .map((z) => z.name)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.displayName),
        actions: [
          IconButton(
            tooltip: 'Mark contacted today',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _markContacted,
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // --- Header: Avatar + Name + Chips ---------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initials: _initials(contact.displayName)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: circleNames
                          .map((n) => _Pill(label: n))
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Stat pills -----------------------------------------------------
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Last contacted',
                  value: _lastContactedLabel(),
                  leading: const Icon(Icons.schedule, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Frequency',
                  value: _cadenceLabel(state),
                  outline: true,
                  leading: const Icon(Icons.repeat, size: 16),
                  onTap: _pickCadenceOverride,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // --- Quick actions --------------------------------------------------
          Text('Quick actions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GradientCta(
                  icon: Icons.message_outlined,
                  label: 'Message',
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/compose',
                      arguments: {'contactId': contact.id},
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              _CircleAction(
                icon: Icons.phone_outlined,
                onTap: () {
                  final number = contact.phones.isNotEmpty
                      ? contact.phones.first
                      : null;
                  if (number == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No phone on file')),
                    );
                    return;
                  }
                  launchCall(context, number);
                },
              ),
              const SizedBox(width: 10),
              _CircleAction(
                icon: Icons.add,
                onTap: () async {
                  // lightweight “add a note” flow
                  final app = InheritedAppState.of(context);
                  final note = await showNoteSheet(context);
                  if (note != null && note.trim().isNotEmpty) {
                    await app.addInteraction(
                      contactId: contact.id,
                      type: 'note',
                      note: note,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note added')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Manage circles / Set frequency as cards -----------------------
          _NavCard(
            icon: Icons.groups_2_outlined,
            title: 'Manage circles',
            subtitle: circleNames.isEmpty
                ? 'No circles'
                : circleNames.join(', '),
            onTap: () => Navigator.pushNamed(context, '/circles'),
          ),
          const SizedBox(height: 10),
          _NavCard(
            icon: Icons.tune_outlined,
            title: 'Set frequency',
            subtitle: 'Currently: ${_cadenceLabel(state)}',
            onTap: _pickCadenceOverride,
          ),
          const SizedBox(height: 20),

          // --- Identity (read-only) ------------------------------------------
          Text('Identity', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            label: 'Primary phone',
            value: contact.phones.isNotEmpty ? contact.phones.first : '—',
          ),
          _ReadOnlyRow(
            label: 'Primary email',
            value: contact.emails.isNotEmpty ? contact.emails.first : '—',
          ),
          const SizedBox(height: 16),

          // --- Time zone & preferred channel ---------------------------------
          _SectionHeader('Timing & channel'),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: tz,
            menuMaxHeight: 360,
            items: _tzOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            selectedItemBuilder: (context) => _tzOptions
                .map(
                  (s) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _shortTzLabel(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Time zone (for smart timing)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => tz = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ContactChannel>(
            initialValue: preferred,
            items: ContactChannel.values
                .map(
                  (c) =>
                      DropdownMenuItem(value: c, child: Text(_channelLabel(c))),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Preferred channel',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                setState(() => preferred = v ?? ContactChannel.none),
          ),
          const SizedBox(height: 20),

          // --- Work / profile -------------------------------------------------
          _SectionHeader('Work & profile'),
          TextField(
            controller: companyCtl,
            decoration: const InputDecoration(
              labelText: 'Company',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleCtl,
            decoration: const InputDecoration(
              labelText: 'Position/Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: locationCtl,
            decoration: const InputDecoration(
              labelText: 'Location',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: linkedinCtl,
            decoration: const InputDecoration(
              labelText: 'LinkedIn (URL or handle)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // --- Availability ---------------------------------------------------
          _SectionHeader('Availability (contact’s local time)'),
          _DayChips(
            selected: availDays,
            onChanged: (set) => setState(() => availDays = set),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _HourField(
                  label: 'Start hour (0–23)',
                  initial: availStart,
                  onChanged: (v) => setState(() => availStart = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HourField(
                  label: 'End hour (0–23)',
                  initial: availEnd,
                  onChanged: (v) => setState(() => availEnd = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Circles & cadence override ------------------------------------
          _SectionHeader('Circles'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.circles.map((circle) {
              final selected = circleIds.contains(circle.id);
              return FilterChip(
                label: Text(circle.name),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    circleIds.add(circle.id);
                  } else {
                    circleIds.remove(circle.id);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // --- Tags & notes ---------------------------------------------------
          _SectionHeader('Tags & notes'),
          TextField(
            controller: tagsCtl,
            decoration: const InputDecoration(
              labelText: 'Tags (comma separated)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Conversation topics, follow-ups, personal context…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '🙂';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}

// == UI bits ==================================================================

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14b8a6), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12)],
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9D5FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF6B21A8),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool outline;
  final Widget? leading;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    this.outline = false,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: outline ? Colors.white : const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(14),
        border: outline ? Border.all(color: const Color(0xFFE5E5E5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle(
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: const Color(0xFF0D9488),
              fontWeight: FontWeight.w700,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Text(title),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    if (onTap == null) return base;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: base,
    );
  }
}

class _GradientCta extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GradientCta({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14b8a6), Color(0xFFA855F7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFCCFBF1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF0D9488)),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF9333EA)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF717182),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: style?.copyWith(color: const Color(0xFF717182)),
            ),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _DayChips extends StatelessWidget {
  final Set<int> selected; // 1..7
  final ValueChanged<Set<int>> onChanged;
  const _DayChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const days = [
      [1, 'Mon'],
      [2, 'Tue'],
      [3, 'Wed'],
      [4, 'Thu'],
      [5, 'Fri'],
      [6, 'Sat'],
      [7, 'Sun'],
    ];
    return Wrap(
      spacing: 8,
      children: days.map((d) {
        final val = d[0] as int;
        final label = d[1] as String;
        final isSel = selected.contains(val);
        return FilterChip(
          label: Text(label),
          selected: isSel,
          onSelected: (v) {
            final next = {...selected};
            v ? next.add(val) : next.remove(val);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

class _HourField extends StatefulWidget {
  final String label;
  final int? initial;
  final ValueChanged<int?> onChanged;
  const _HourField({
    required this.label,
    this.initial,
    required this.onChanged,
  });

  @override
  State<_HourField> createState() => _HourFieldState();
}

class _HourFieldState extends State<_HourField> {
  late final TextEditingController ctl;
  @override
  void initState() {
    super.initState();
    ctl = TextEditingController(text: widget.initial?.toString() ?? '');
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n == null || n < 0 || n > 23) {
          widget.onChanged(null);
        } else {
          widget.onChanged(n);
        }
      },
    );
  }
}

// A lightweight curated TZ list for MVP.
const List<String> _tzOptions = [
  'System default',
  'UTC (UTC+00:00)',
  'America/New_York (UTC-05:00/UTC-04:00)',
  'America/Los_Angeles (UTC-08:00/UTC-07:00)',
  'Europe/London (UTC+00:00/UTC+01:00)',
  'Europe/Berlin (UTC+01:00/UTC+02:00)',
  'Asia/Kolkata (UTC+05:30)',
  'Asia/Singapore (UTC+08:00)',
  'Australia/Sydney (UTC+10:00/UTC+11:00)',
];

String _channelLabel(ContactChannel c) {
  switch (c) {
    case ContactChannel.none:
      return 'None';
    case ContactChannel.call:
      return 'Call';
    case ContactChannel.sms:
      return 'SMS';
    case ContactChannel.whatsapp:
      return 'WhatsApp';
    case ContactChannel.email:
      return 'Email';
  }
}

String _shortTzLabel(String full) {
  final i = full.indexOf(' (UTC');
  return i > 0 ? full.substring(0, i) : full;
}
