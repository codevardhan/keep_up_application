import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/circle.dart';
import '../../../router.dart';

class CirclesPage extends StatelessWidget {
  const CirclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final circles = state.circles;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Circles')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) {
          final c = circles[i];
          return Card(
            child: ListTile(
              title: Text(c.name),
              subtitle: Text('Cadence: ${c.cadence.name}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.circleDetail,
                  arguments: {'circleId': c.id},
                );
              },
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: circles.length,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Minimal add circle dialog
          final nameCtrl = TextEditingController();
          Cadence cad = Cadence.monthly;
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('New Circle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<Cadence>(
                    value: cad,
                    isExpanded: true,
                    onChanged: (v) {
                      cad = v ?? Cadence.monthly;
                      (ctx as Element).markNeedsBuild();
                    },
                    items: Cadence.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
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
            final newCircle = Circle(
              id: id,
              name: nameCtrl.text.trim(),
              cadence: cad,
            );
            final updated = [...state.circles, newCircle];
            await state.setCircles(updated);
          }
        },
        label: const Text('Add Circle'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
