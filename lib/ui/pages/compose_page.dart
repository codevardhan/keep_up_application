// lib/ui/pages/compose/compose_page.dart
import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../core/deeplink.dart';
import '../theme/app_theme.dart';
import '../widgets/note_sheet.dart';

class ComposePage extends StatefulWidget {
  final String? contactId;
  final String? initialText; // prefill from notifications

  const ComposePage({super.key, this.contactId, this.initialText});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  late final TextEditingController controller;
  String _tone = 'warm'; // warm | brief | pro
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

  String _templateFor({
    required String tone,
    required String? firstName,
    required String? goal,
  }) {
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
    required String type, // 'sms' | 'whatsapp' | 'call' | 'generic'
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

    if (controller.text.isEmpty && !_isPrefilled) {
      _applyTemplate(state);
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBg),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // header card with avatar + hint
              DecoratedBox(
                decoration: AppDecor.card(
                  color: AppColors.white,
                ).copyWith(boxShadow: AppShadows.small),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      _Avatar(initials: _initials(_contactTitle(state))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_contactTitle(state), style: AppText.h3),
                            const SizedBox(height: 4),
                            Text(
                              _isPrefilled
                                  ? 'Suggested text — edit before sending.'
                                  : 'Start with a friendly tone and make it specific.',
                              style: AppText.caption.copyWith(
                                color: AppColors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // tone control
              DecoratedBox(
                decoration: AppDecor.card(color: AppColors.white),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tone', style: AppText.bodySemi),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'warm', label: Text('Warm')),
                          ButtonSegment(value: 'brief', label: Text('Brief')),
                          ButtonSegment(
                            value: 'pro',
                            label: Text('Professional'),
                          ),
                        ],
                        selected: {_tone},
                        onSelectionChanged: (set) {
                          setState(() {
                            _tone = set.first;
                            _applyTemplate(state);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // editor
              DecoratedBox(
                decoration: AppDecor.card(color: AppColors.white),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: controller,
                    maxLines: 8,
                    onChanged: (_) {
                      if (!_isPrefilled) _isPrefilled = true;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Type or edit your message…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // quick actions (wrap; fits content; wraps only when needed)
              DecoratedBox(
                decoration: AppDecor.card(color: AppColors.white),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick actions', style: AppText.bodySemi),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PillButton.gradient(
                            icon: Icons.sms_outlined,
                            label: 'SMS',
                            onTap: (cv.phone == null)
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
                          _PillButton.ghost(
                            icon: Icons.chat, // no WA glyph in Material
                            label: 'WhatsApp',
                            onTap: (cv.phone == null)
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
                          _PillButton.ghost(
                            icon: Icons.phone_outlined,
                            label: 'Call',
                            onTap: (cv.phone == null)
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // send button (full-width gradient)
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppGradients.cta,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  boxShadow: AppShadows.medium,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: ButtonStyle(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 14),
                      ),
                      foregroundColor: const WidgetStatePropertyAll<Color>(
                        Colors.white,
                      ),
                      overlayColor: const WidgetStatePropertyAll<Color>(
                        Colors.white24,
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
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
                    child: Text('Send', style: AppText.button),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _contactTitle(AppState state) {
    final id = widget.contactId;
    if (id == null) return 'Message';
    final idx = state.contacts.indexWhere((c) => c.id == id);
    if (idx < 0) return 'Message';
    return state.contacts[idx].displayName;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.take(2).toString();
    return ('${parts.first.characters.take(1)}${parts.last.characters.take(1)}')
        .toUpperCase();
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


// --- Tiny gradient initials avatar ------------------------------------------------
class _Avatar extends StatelessWidget {
  final String initials;
  final double size;

  const _Avatar({required this.initials, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradients.cta,
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            initials.toUpperCase(),
            style: AppText.bodySemi.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}


// --- Small reusable pill button (wrap-friendly, fits content) ---------------

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ButtonStyle style;
  final bool gradient;

  const _PillButton._({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.style,
    required this.gradient,
  });

  factory _PillButton.gradient({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return _PillButton._(
      icon: icon,
      label: label,
      onTap: onTap,
      gradient: true,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.white24),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
      ),
    );
  }

  factory _PillButton.ghost({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return _PillButton._(
      icon: icon,
      label: label,
      onTap: onTap,
      gradient: false,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neutral700,
        side: const BorderSide(color: AppColors.neutral300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label, style: AppText.bodySemi),
      ],
    );

    if (gradient) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppGradients.cta,
          borderRadius: BorderRadius.all(Radius.circular(14)),
          boxShadow: AppShadows.soft,
        ),
        child: TextButton(onPressed: onTap, style: style, child: child),
      );
    }

    return TextButton(onPressed: onTap, style: style, child: child);
  }
}
