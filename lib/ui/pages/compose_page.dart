import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../core/deeplink.dart';
import '../widgets/note_sheet.dart';

class ComposePage extends StatefulWidget {
  final String? contactId;
  final String? initialText; // <-- new: prefill from notifications, etc.

  const ComposePage({super.key, this.contactId, this.initialText});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  late final TextEditingController controller;
  String _tone = 'warm'; // warm | brief | pro

  /// When true, we won’t auto-override the editor from tone changes.
  bool _isPrefilled = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialText ?? '');
    _isPrefilled =
        (widget.initialText != null && widget.initialText!.trim().isNotEmpty);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _contactName(AppState state) {
    final id = widget.contactId;
    if (id == null) return 'Message';
    final idx = state.contacts.indexWhere((c) => c.id == id);
    if (idx < 0) return 'Message';
    return 'Message ${state.contacts[idx].displayName}';
  }

  /// Build a simple template from tone + (optional) goal + (optional) first name.
  String _templateFor({
    required String tone,
    required String? firstName,
    required String? goal,
  }) {
    // final name = (firstName == null || firstName.isEmpty) ? '' : '$firstName, ';
    final g = (goal == null || goal.isEmpty) ? 'catch up' : 'talk about $goal';

    switch (tone) {
      case 'brief':
        return 'Hi${firstName == null ? '' : ' $firstName'}—could we find 10 minutes this week to $g?';
      case 'pro':
        return 'Hello${firstName == null ? '' : ' $firstName'}, I’m hoping to $g this week. Would a short call work for you?';
      case 'warm':
      default:
        return 'Hey ${firstName ?? ''}! I’m hoping to $g this week—could we grab 10 minutes to chat?';
    }
  }

  /// Apply (or re-apply) the template when tone/contact/goal changes.
  void _applyTemplate(AppState state) {
    if (_isPrefilled) return; // don’t clobber AI/notification text
    final contact = _getContact(state);
    final first = contact?.displayName.split(' ').first;
    final goal = state.activeGoal?.label;
    final text = _templateFor(tone: _tone, firstName: first, goal: goal);
    controller.text = text;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  _ContactView _contactView(AppState state) {
    final c = _getContact(state);
    final phone = (c?.phones.isNotEmpty ?? false) ? c!.phones.first : null;
    return _ContactView(id: c?.id, displayName: c?.displayName, phone: phone);
  }

  // Helper to fetch contact based on contactId
  _Contact? _getContact(AppState state) {
    final id = widget.contactId;
    if (id == null) return null;
    final idx = state.contacts.indexWhere((c) => c.id == id);
    if (idx < 0) return null;
    final c = state.contacts[idx];
    return _Contact(id: c.id, displayName: c.displayName, phones: c.phones);
  }

  Future<void> _showMarkSnack(
    BuildContext context,
    AppState state,
    String? contactId,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pretend message sent. Mark as contacted today?'),
        action: (contactId == null)
            ? null
            : SnackBarAction(
                label: 'Mark',
                onPressed: () async {
                  await state.markContactedNow(contactId);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Contacted today.'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () async {
                          final i = state.contacts.indexWhere(
                            (c) => c.id == contactId,
                          );
                          if (i >= 0) {
                            final c = state.contacts[i];
                            state.contacts[i] = c.copyWith(
                              lastContactedAt: null,
                            );
                            await state.setContacts(state.contacts);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _afterSendAddNote({
    required BuildContext context,
    required AppState state,
    required String type, // 'sms' | 'whatsapp' | 'call'
    required String? contactId,
  }) async {
    if (!mounted || contactId == null) return;
    final text = await showNoteSheet(context);
    if (text != null && text.trim().isNotEmpty) {
      await state.addInteraction(contactId: contactId, type: type, note: text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final title = _contactName(state);
    final cv = _contactView(state);

    // Initialize template if this is the first build and not prefilled
    if (controller.text.isEmpty && !_isPrefilled) {
      _applyTemplate(state);
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isPrefilled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Suggested text — edit before sending.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'warm', label: Text('Warm')),
                ButtonSegment(value: 'brief', label: Text('Brief')),
                ButtonSegment(value: 'pro', label: Text('Professional')),
              ],
              selected: {_tone},
              onSelectionChanged: (set) {
                setState(() {
                  _tone = set.first;
                  _applyTemplate(state);
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type or edit your message…',
              ),
              onChanged: (_) {
                // User typed → treat as custom text and stop auto-overwriting
                if (!_isPrefilled) _isPrefilled = true;
              },
            ),

            const SizedBox(height: 12),
            // Quick deep links (disabled if no phone)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('SMS'),
                  onPressed: (cv.phone == null)
                      ? null
                      : () async {
                          await launchSms(
                            context,
                            cv.phone!,
                            body: controller.text,
                          );
                          if (!mounted) return;
                          await _showMarkSnack(context, state, cv.id);
                          await _afterSendAddNote(
                            context: context,
                            state: state,
                            type: 'sms',
                            contactId: cv.id,
                          );
                          if (mounted) Navigator.pop(context);
                        },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat), // no WA glyph in Material
                  label: const Text('WhatsApp'),
                  onPressed: (cv.phone == null)
                      ? null
                      : () async {
                          await launchWhatsApp(
                            context,
                            cv.phone!,
                            text: controller.text,
                          );
                          if (!mounted) return;
                          await _showMarkSnack(context, state, cv.id);
                          await _afterSendAddNote(
                            context: context,
                            state: state,
                            type: 'whatsapp',
                            contactId: cv.id,
                          );
                          if (mounted) Navigator.pop(context);
                        },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Call'),
                  onPressed: (cv.phone == null)
                      ? null
                      : () async {
                          await launchCall(context, cv.phone!);
                          if (!mounted) return;
                          await _showMarkSnack(context, state, cv.id);
                          await _afterSendAddNote(
                            context: context,
                            state: state,
                            type: 'call',
                            contactId: cv.id,
                          );
                          if (mounted) Navigator.pop(context);
                        },
                ),
              ],
            ),

            const Spacer(),
            // Generic "Send" for demo flow if you don't use the deep links above.
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await _showMarkSnack(context, state, cv.id);
                  await _afterSendAddNote(
                    context: context,
                    state: state,
                    type: 'generic',
                    contactId: cv.id,
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contact {
  final String id;
  final String displayName;
  final List<String> phones;
  _Contact({required this.id, required this.displayName, required this.phones});
}

class _ContactView {
  final String? id;
  final String? displayName;
  final String? phone;
  _ContactView({this.id, this.displayName, this.phone});
}
