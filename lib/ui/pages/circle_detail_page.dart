import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../models/circle.dart';
import '../../../router.dart';

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
      appBar: AppBar(title: Text(circle.name)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Cadence row
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

          // Members
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        await state.removeContactFromCircle(m.id, circle.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),

          // All Contacts header + filter controls
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text(
                  'All Contacts',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                if (_query.isNotEmpty || _onlyWithPhone)
                  Text(
                    '(${filteredNonMembers.length})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          // Search field
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
          const SizedBox(height: 8),
          // Only-with-phone toggle
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Only show contacts with a phone number'),
            value: _onlyWithPhone,
            onChanged: (v) => setState(() => _onlyWithPhone = v),
          ),
          const SizedBox(height: 8),
          if (filteredNonMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No contacts match your filter.'),
            ),

          // Filtered non-members list
          ...filteredNonMembers.map(
            (c) => Card(
              child: ListTile(
                title: Text(c.displayName),
                subtitle: Text(
                  c.phones.isNotEmpty
                      ? c.phones.first
                      : (c.emails.isNotEmpty ? c.emails.first : ''),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
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
    );
  }
}
