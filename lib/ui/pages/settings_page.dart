// lib/ui/pages/settings/settings_page.dart
import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../services/contacts_sync.dart';
import '../../../models/prefs.dart';

// Existing services you already use
import '../../../services/notification_service.dart';
import '../../../services/ai_suggestion_service.dart';
import '../../../models/goal.dart';

// Theme helpers
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = InheritedAppState.of(context);
    final prefs = appState.prefs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.pageBg),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ===== Section: Circles & frequency / Suggestions behavior =====
            const _SectionHeader(
              icon: Icons.favorite_outline,
              label: 'Suggestions',
            ),

            // Quiet hours
            _SettingCard(
              leading: _IconBadge(icon: Icons.nightlight_outlined),
              title: 'Quiet hours',
              subtitle: 'Reduce nudges during your off times',
              trailing: Switch(
                value: prefs.quietHours,
                onChanged: (v) =>
                    appState.setPrefs(prefs.copyWith(quietHours: v)),
              ),
              onTap: () => appState.setPrefs(
                prefs.copyWith(quietHours: !prefs.quietHours),
              ),
            ),

            const SizedBox(height: 10),

            // Outreach window picker
            _SettingCard(
              leading: _IconBadge(icon: Icons.schedule_outlined),
              title: 'Outreach window',
              subtitle: _windowLabel(prefs.window),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.neutral400,
              ),
              onTap: () async {
                final picked = await showModalBottomSheet<OutreachWindow>(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  builder: (_) => _WindowPickerSegmented(current: prefs.window),
                );
                if (picked != null) {
                  await appState.setPrefs(prefs.copyWith(window: picked));
                }
              },
            ),

            const SizedBox(height: 10),

            // Holiday-aware
            _SettingCard(
              leading: _IconBadge(icon: Icons.event_available_outlined),
              title: 'Holiday-aware suggestions',
              subtitle: 'Include cultural/locale events in prompts',
              trailing: Switch(
                value: prefs.holidayAware,
                onChanged: (v) =>
                    appState.setPrefs(prefs.copyWith(holidayAware: v)),
              ),
              onTap: () => appState.setPrefs(
                prefs.copyWith(holidayAware: !prefs.holidayAware),
              ),
            ),

            const SizedBox(height: 20),

            // ===== Section: Demo =====
            const _SectionHeader(icon: Icons.bolt_outlined, label: 'Demo'),

            _CTAButton(
              icon: Icons.notifications_active_outlined,
              label: 'Send demo suggestion notification',
              sublabel: 'Picks a contact in your circles and uses AI',
              onPressed: () async {
                final contacts = appState.contacts;
                if (contacts.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No contacts available. Import first.'),
                      ),
                    );
                  }
                  return;
                }

                final inCircle = contacts.where((c) => c.circleIds.isNotEmpty);
                final contact = inCircle.isNotEmpty
                    ? inCircle.first
                    : contacts.first;

                final goal = appState.activeGoal?.type ?? GoalType.friends;
                final circleNames = appState.circles
                    .where((ci) => contact.circleIds.contains(ci.id))
                    .map((ci) => ci.name)
                    .toList();

                final message =
                    await AiSuggestionService.generateNotificationLine(
                      goalType: goal,
                      circleNames: circleNames,
                      lastNote: contact.notes,
                    );

                String preview = message.split(RegExp(r'[.!?]')).first.trim();
                if (preview.length > 60) {
                  preview = '${preview.substring(0, 60)}…';
                }

                await NotificationService.showSuggestionNow(
                  contactId: contact.id,
                  title: 'Check in',
                  body: message, // full text visible in BigText
                  longText: message, // ensure expanded shows the same
                  prefilledMessage: message,
                  tag: contact.id,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Demo notification sent for ${contact.displayName}.',
                      ),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            // ===== Section: Contacts =====
            const _SectionHeader(icon: Icons.people_outline, label: 'Contacts'),

            _SettingCard(
              leading: _IconBadge(icon: Icons.sync),
              title: 'Sync contacts from device',
              subtitle: 'Imported: ${appState.contacts.length}',
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.neutral400,
              ),
              onTap: () async {
                final list = await ContactsSync.fetchDeviceContacts();
                if (list.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Permission denied or no contacts found.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                await appState.setContacts(list);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Imported ${list.length} contacts.'),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            // ===== Section: Maintenance =====
            const _SectionHeader(
              icon: Icons.tune_outlined,
              label: 'Maintenance',
            ),

            _SettingCard(
              leading: _IconBadge(icon: Icons.restart_alt),
              title: 'Reset onboarding',
              subtitle: 'Show onboarding on next launch',
              onTap: () async {
                await InheritedAppState.of(context).setOnboardingSeen(false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Onboarding reset')),
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            // ===== Section: Info =====
            const _SectionHeader(icon: Icons.info_outline, label: 'Info'),
            _InfoTile(
              title: 'Permissions',
              subtitle: 'Contacts (required), Calendar (optional)',
            ),
            const SizedBox(height: 8),
            _InfoTile(
              title: 'About data',
              subtitle: 'Stored locally with SharedPreferences (JSON).',
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── UI helpers ──────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.purple500, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppText.overline.copyWith(color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.teal100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: AppColors.teal600, size: 18),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingCard({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: leading,
        title: Text(title, style: AppText.bodySemi),
        subtitle: (subtitle == null)
            ? null
            : Text(subtitle!, style: AppText.caption),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onPressed;

  const _CTAButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.cta,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.medium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppText.bodySemi.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        style: AppText.caption.copyWith(
                          color: Colors.white.withOpacity(.95),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  const _InfoTile({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.bodySemi),
          const SizedBox(height: 4),
          Text(subtitle, style: AppText.caption),
        ],
      ),
    );
  }
}

// ───────────────────── Picker bottom sheet (unchanged logic) ─────────────────────

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
            Text('Choose outreach window', style: AppText.bodySemi),
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
