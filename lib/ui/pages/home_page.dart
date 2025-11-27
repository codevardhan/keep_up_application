import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = InheritedAppState.of(context);
    final goalLabel = appState.activeGoal?.label ?? 'No goal selected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('KeepUp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current goal',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              goalLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('Next steps'),
            Card(
              child: ListTile(
                title: const Text('Manage circles'),
                subtitle: const Text('Members & reminder cadence'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.circles),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('See suggestions'),
                subtitle: const Text('2–3 people to reach out to'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.suggestions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
