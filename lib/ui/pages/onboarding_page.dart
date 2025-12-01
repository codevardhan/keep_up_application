import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/goal.dart';
import '../widgets/goal_chip.dart';
import '../../../router.dart';
import '../../../services/contacts_sync.dart';
import '../../../models/app_contact.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0; // 0: pick goal, 1: import contacts
  Goal? selectedGoal;

  bool importing = false;
  List<AppContact> importedContacts = const [];

  final goals = const [
    Goal(GoalType.internship, 'Find an internship'),
    Goal(GoalType.family, 'Reconnect with family'),
    Goal(GoalType.friends, 'Keep up with friends'),
    Goal(GoalType.wellness, 'De-stress & balance'),
  ];

  Future<void> _doImport(AppState appState) async {
    setState(() => importing = true);
    try {
      final list = await ContactsSync.fetchDeviceContacts();
      setState(() => importedContacts = list);
      if (list.isNotEmpty) {
        await appState.setContacts(list);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${list.length} contacts')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied or no contacts found'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  void _finishOnboarding(AppState appState) {
    appState.setOnboardingSeen(true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = InheritedAppState.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: step == 0
            ? _StepChooseGoal(
                goals: goals,
                selected: selectedGoal,
                onSelect: (g) => setState(() => selectedGoal = g),
                onContinue: selectedGoal == null
                    ? null
                    : () {
                        appState.setGoal(selectedGoal!);
                        setState(() => step = 1);
                      },
              )
            : _StepImportContacts(
                importing: importing,
                importedCount: importedContacts.length,
                onImport: () => _doImport(appState),
                onSkipOrFinish: () => _finishOnboarding(appState), // <-- step 4
              ),
      ),
    );
  }
}

class _StepChooseGoal extends StatelessWidget {
  final List<Goal> goals;
  final Goal? selected;
  final ValueChanged<Goal> onSelect;
  final VoidCallback? onContinue;

  const _StepChooseGoal({
    required this.goals,
    required this.selected,
    required this.onSelect,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What’s your focus this week?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goals
              .map(
                (g) => GoalChip(
                  goal: g,
                  selected: selected?.type == g.type,
                  onTap: () => onSelect(g),
                ),
              )
              .toList(),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onContinue,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}

class _StepImportContacts extends StatelessWidget {
  final bool importing;
  final int importedCount;
  final VoidCallback onImport;
  final VoidCallback onSkipOrFinish;

  const _StepImportContacts({
    required this.importing,
    required this.importedCount,
    required this.onImport,
    required this.onSkipOrFinish,
  });

  @override
  Widget build(BuildContext context) {
    final hasImported = importedCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import contacts (optional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'KeepUp reads device contacts (name/phone/email) to suggest the right people at the right time. '
          'Stored locally; change anytime in Settings.',
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: importing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            title: Text(
              hasImported
                  ? 'Imported $importedCount contacts'
                  : 'Sync contacts from device',
            ),
            subtitle: Text(
              hasImported
                  ? 'You can re-sync later in Settings'
                  : 'One tap, read-only',
            ),
            trailing: importing
                ? null
                : FilledButton(
                    onPressed: onImport,
                    child: const Text('Import'),
                  ),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            TextButton(onPressed: onSkipOrFinish, child: const Text('Skip')),
            const Spacer(),
            FilledButton(
              onPressed: onSkipOrFinish,
              child: Text(hasImported ? 'Finish' : 'Continue'),
            ),
          ],
        ),
      ],
    );
  }
}
