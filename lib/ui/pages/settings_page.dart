import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../services/contacts_sync.dart';
import '../../../models/prefs.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = InheritedAppState.of(context);
    final prefs = appState.prefs;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- Suggestions behavior ----
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(
              'Suggestions',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SwitchListTile(
            title: const Text('Quiet hours'),
            subtitle: const Text('Reduce nudges during your off times'),
            value: prefs.quietHours,
            onChanged: (v) => appState.setPrefs(prefs.copyWith(quietHours: v)),
          ),
          ListTile(
            title: const Text('Outreach window'),
            subtitle: Text(_windowLabel(prefs.window)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showModalBottomSheet<OutreachWindow>(
                context: context,
                builder: (_) => _WindowPickerSegmented(current: prefs.window),
              );
              if (picked != null) {
                await appState.setPrefs(prefs.copyWith(window: picked));
              }
            },
          ),
          SwitchListTile(
            title: const Text('Holiday-aware suggestions'),
            subtitle: const Text('Include cultural/locale events in prompts'),
            value: prefs.holidayAware,
            onChanged: (v) =>
                appState.setPrefs(prefs.copyWith(holidayAware: v)),
          ),

          const Divider(height: 24),

          // ---- Contacts sync ----
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(
              'Contacts',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync contacts from device'),
            subtitle: Text('Imported: ${appState.contacts.length}'),
            onTap: () async {
              final list = await ContactsSync.fetchDeviceContacts();
              if (list.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permission denied or no contacts found.'),
                    ),
                  );
                }
                return;
              }
              await appState.setContacts(list);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported ${list.length} contacts.')),
                );
              }
            },
          ),

          const Divider(height: 24),

          // ---- Info ----
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('Info', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const ListTile(
            title: Text('Permissions'),
            subtitle: Text('Contacts (required), Calendar (optional)'),
          ),
          const ListTile(
            title: Text('About data'),
            subtitle: Text('Stored locally with SharedPreferences (JSON).'),
          ),
        ],
      ),
    );
  }
}

String _windowLabel(OutreachWindow w) {
  switch (w) {
    case OutreachWindow.anytime:
      return 'Anytime';
    case OutreachWindow.evenings:
      return 'Evenings';
    case OutreachWindow.weekends:
      return 'Weekends';
  }
}

class _WindowPickerSegmented extends StatefulWidget {
  final OutreachWindow current;
  const _WindowPickerSegmented({required this.current});

  @override
  State<_WindowPickerSegmented> createState() => _WindowPickerSegmentedState();
}

class _WindowPickerSegmentedState extends State<_WindowPickerSegmented> {
  late OutreachWindow _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose outreach window',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<OutreachWindow>(
              segments: const [
                ButtonSegment(
                  value: OutreachWindow.anytime,
                  label: Text('Anytime'),
                ),
                ButtonSegment(
                  value: OutreachWindow.evenings,
                  label: Text('Evenings'),
                ),
                ButtonSegment(
                  value: OutreachWindow.weekends,
                  label: Text('Weekends'),
                ),
              ],
              selected: {_selected},
              onSelectionChanged: (set) =>
                  setState(() => _selected = set.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
