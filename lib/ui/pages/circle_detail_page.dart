import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/circle.dart';

class CircleDetailPage extends StatefulWidget {
  final String circleId;
  const CircleDetailPage({super.key, required this.circleId});

  @override
  State<CircleDetailPage> createState() => _CircleDetailPageState();
}

class _CircleDetailPageState extends State<CircleDetailPage> {
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

    return Scaffold(
      appBar: AppBar(title: Text(circle.name)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            title: const Text('Cadence'),
            subtitle: Text(circle.cadence.name),
            trailing: DropdownButton<Cadence>(
              value: circle.cadence,
              onChanged: (v) async {
                if (v == null) return;
                final updated = state.circles.map((c) {
                  if (c.id == circle.id) return c.copyWith(cadence: v);
                  return c;
                }).toList();
                await state.setCircles(updated);
                setState(() {});
              },
              items: Cadence.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
            ),
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Members',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No members yet. Add from your contacts below.'),
            ),
          ...members.map(
            (m) => Card(
              child: ListTile(
                title: Text(m.displayName),
                subtitle: Text(
                  m.phones.isNotEmpty
                      ? m.phones.first
                      : (m.emails.isNotEmpty ? m.emails.first : ''),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async {
                    await state.removeContactFromCircle(m.id, circle.id);
                    setState(() {});
                  },
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'All Contacts',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ...nonMembers.map(
            (c) => Card(
              child: ListTile(
                title: Text(c.displayName),
                subtitle: Text(
                  c.phones.isNotEmpty
                      ? c.phones.first
                      : (c.emails.isNotEmpty ? c.emails.first : ''),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    await state.addContactToCircle(c.id, circle.id);
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
