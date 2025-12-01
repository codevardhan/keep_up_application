// lib/ui/pages/contact_edit_page.dart
import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/app_contact.dart';
import '../../../models/circle.dart';

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
  void initState() {
    super.initState();
    // Real initialization done in didChangeDependencies once we have state
  }

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
      notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
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
    setState(() {}); // refresh subtitle
  }

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final circles = state.circles;

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
        padding: const EdgeInsets.all(16),
        children: [
          // Basic immutable identity shown
          _ReadOnlyRow(
            label: 'Primary phone',
            value: contact.phones.isNotEmpty ? contact.phones.first : '—',
          ),
          _ReadOnlyRow(
            label: 'Primary email',
            value: contact.emails.isNotEmpty ? contact.emails.first : '—',
          ),
          const SizedBox(height: 8),

          // Time zone + preferred channel
          // Time zone (overflow-safe) + preferred channel
          DropdownButtonFormField<String>(
            initialValue: tz,
            isExpanded: true, // ← use full width, prevents right overflow
            menuMaxHeight: 360,
            items: _tzOptions.map((s) {
              return DropdownMenuItem<String>(
                value: s,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 320,
                  ), // tweak if needed
                  child: Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // ← truncate long options
                  ),
                ),
              );
            }).toList(),
            // Show a shorter label when the field is closed
            selectedItemBuilder: (context) {
              return _tzOptions.map((s) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _shortTzLabel(s), // e.g., "Asia/Kolkata"
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList();
            },
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
          const SizedBox(height: 16),

          // Work / profile
          _SectionHeader('Work & Profile'),
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
          const SizedBox(height: 16),

          // Availability
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
                  label: 'Start hour (0-23)',
                  initial: availStart,
                  onChanged: (v) => setState(() => availStart = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HourField(
                  label: 'End hour (0-23)',
                  initial: availEnd,
                  onChanged: (v) => setState(() => availEnd = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Circles + cadence override
          _SectionHeader('Circles & Cadence'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: circles.map((circle) {
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
          const SizedBox(height: 8),
          DropdownButtonFormField<Cadence?>(
            initialValue: cadenceOverride,
            items: <DropdownMenuItem<Cadence?>>[
              const DropdownMenuItem<Cadence?>(
                value: null,
                child: Text('Use circle cadence (default)'),
              ),
              ...Cadence.values.map(
                (c) => DropdownMenuItem<Cadence?>(
                  value: c,
                  child: Text('Override: ${c.name}'),
                ),
              ),
            ],
            decoration: const InputDecoration(
              labelText: 'Reminder cadence (override)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => cadenceOverride = v),
          ),
          const SizedBox(height: 16),

          // Tags & notes
          _SectionHeader('Tags & Notes'),
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
          SizedBox(width: 140, child: Text(label, style: style)),
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
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

class _DayChips extends StatelessWidget {
  final Set<int> selected; // 1..7
  final ValueChanged<Set<int>> onChanged;
  const _DayChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final days = const [
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

// A lightweight curated list for MVP. You can expand/replace with a full tz db later.
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
  // Keep the TZ ID and drop the UTC detail to reduce width.
  final i = full.indexOf(' (UTC');
  return i > 0 ? full.substring(0, i) : full;
}
