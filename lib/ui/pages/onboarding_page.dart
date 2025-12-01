// lib/ui/pages/onboarding/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import '../../../core/app_state.dart';
import '../../../router.dart';
import '../theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../../../services/contacts_sync.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _idx = 0;

  // 5 steps (Welcome, Problem, How, Notifications, Contacts)
  static const _total = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If onboarding is already completed, never show this again.
    final state = InheritedAppState.of(context);
    if (state.onboardingSeen) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_idx < _total - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final state = InheritedAppState.of(context);
    await state.setOnboardingSeen(true);
    if (!mounted) return;
    // Replace stack so the back button can't return to onboarding
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  /// Require explicit notification permission before advancing.
  Future<void> _handleNotificationsGate() async {
    // Request via your service (ensures init + prompt where needed)
    await NotificationService.requestPermissions();

    // Also verify using Awesome Notifications directly.
    var allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed && mounted) {
      // Some devices need an explicit second call to open settings page
      await AwesomeNotifications().requestPermissionToSendNotifications();
      allowed = await AwesomeNotifications().isNotificationAllowed();
    }

    if (allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notifications enabled')));
      await _goNext();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable notifications to continue.'),
        ),
      );
    }
  }

  /// Require contacts permission (and at least one visible contact) before advancing.
  Future<void> _handleContactsGate() async {
    final list = await ContactsSync.fetchDeviceContacts();
    if (!mounted) return;

    if (list.isNotEmpty) {
      await InheritedAppState.of(context).setContacts(list);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${list.length} contacts')),
      );
      await _goNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contacts permission required. Please allow to continue.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Block system back during onboarding
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => {
        if (!didPop)
          {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Finish onboarding to continue')),
            ),
          },
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.pageBg),
          child: SafeArea(
            bottom: true,
            child: Column(
              children: [
                // Top segmented progress
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _ProgressBar(current: _idx, total: _total),
                ),

                // Pages (swipe disabled to prevent skipping)
                Expanded(
                  child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _idx = i),
                    children: [
                      _OnbPage(
                        hero: const _HeroPlaceholder(
                          icon: Icons.favorite_outline,
                          bg: AppColors.purple100,
                          fg: AppColors.purple600,
                        ),
                        title: 'Keep your people close, effortlessly.',
                        body:
                            'KeepUp helps you remember to check in with the people who matter. Gentle nudges to call, text, or meet—before months silently pass.',
                        primaryText: 'Continue',
                        onPrimary: _goNext,
                      ),
                      _OnbPage(
                        hero: const _HeroPlaceholder(
                          icon: Icons.calendar_today_outlined,
                          bg: AppColors.teal100,
                          fg: AppColors.teal600,
                        ),
                        title:
                            'Life gets busy. People slip through the cracks.',
                        body:
                            'Work, studies, and daily chaos make it easy to lose touch. KeepUp nudges you before “let’s catch up soon” becomes “it’s been a year already?”',
                        primaryText: 'Continue',
                        onPrimary: _goNext,
                      ),
                      _OnbPage(
                        hero: const _FlowTriptych(),
                        title: 'Set your connection goals.',
                        body:
                            '• Pick who you want to stay close to—family, friends, mentors.\n• Choose how often you want to reconnect.\n• We remind you at the right time; you choose call, text, or meet.',
                        primaryText: 'Continue',
                        onPrimary: _goNext,
                      ),
                      _OnbPage(
                        hero: const _HeroPlaceholder(
                          icon: Icons.notifications_active_outlined,
                          bg: AppColors.e9ebef,
                          fg: AppColors.neutral700,
                        ),
                        title:
                            'We use notifications—only for you, never to spam.',
                        body:
                            'We’ll notify you about:\n• Check-in reminders you set\n• Special dates you choose\n• Optional weekly summaries\nYou’re always in control.',
                        primaryText: 'Allow & Continue',
                        onPrimary: _handleNotificationsGate,
                      ),
                      _OnbPage(
                        hero: const _HeroPlaceholder(
                          icon: Icons.contacts_outlined,
                          bg: AppColors.f3,
                          fg: AppColors.neutral700,
                        ),
                        title: 'We use your contacts to save you time.',
                        body:
                            'Skip manual typing by letting KeepUp read names/phones/emails locally. We never message your contacts automatically, and never sell or share your list.',
                        primaryText: 'Allow & Finish',
                        onPrimary: _handleContactsGate,
                      ),
                    ],
                  ),
                ),

                // Bottom controls: only a primary "Next" / "Finish" mirror (no Skip)
                // Padding(
                //   padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                //   child: SizedBox(
                //     width: double.infinity,
                //     child: FilledButton(
                //       onPressed: () async {
                //         // Mirror the page CTAs so users can press bottom button too.
                //         switch (_idx) {
                //           case 3:
                //             await _handleNotificationsGate();
                //             break;
                //           case 4:
                //             await _handleContactsGate();
                //             break;
                //           default:
                //             await _goNext();
                //         }
                //       },
                //       child: Text(_idx == _total - 1 ? 'Finish' : 'Continue'),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Widgets --------------------------------

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(total, (i) {
      final isDone = i < current;
      final isCurrent = i == current;
      final color = isCurrent
          ? AppColors.teal500
          : (isDone ? AppColors.teal300 : AppColors.neutral200);
      return Expanded(
        child: Container(
          height: 6,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    });

    return Row(children: items);
  }
}

class _OnbPage extends StatelessWidget {
  final Widget hero;
  final String title;
  final String body;
  final String primaryText;
  final VoidCallback onPrimary;

  const _OnbPage({
    required this.hero,
    required this.title,
    required this.body,
    required this.primaryText,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Expanded(child: Center(child: hero)),
          const SizedBox(height: 8),
          Text(title, style: AppText.h1, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            body,
            style: AppText.body.copyWith(color: AppColors.neutral600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onPrimary, child: Text(primaryText)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Simple hero placeholder: soft card with icon (designer can replace with actual art)
class _HeroPlaceholder extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _HeroPlaceholder({
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card * 1.5),
        boxShadow: AppShadows.soft,
      ),
      child: Icon(icon, color: fg, size: 88),
    );
  }
}

/// A 3-panel flow placeholder for “How it works”
class _FlowTriptych extends StatelessWidget {
  const _FlowTriptych();

  @override
  Widget build(BuildContext context) {
    Widget card(IconData icon, String label, Color bg, Color fg) {
      return Expanded(
        child: Container(
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.small,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppText.small.copyWith(color: AppColors.neutral700),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          card(
            Icons.flag_outlined,
            'Pick goal',
            AppColors.teal100,
            AppColors.teal600,
          ),
          card(
            Icons.notifications_none,
            'Get nudge',
            AppColors.purple100,
            AppColors.purple600,
          ),
          card(
            Icons.call_outlined,
            'Reach out',
            AppColors.f5,
            AppColors.neutral700,
          ),
        ],
      ),
    );
  }
}
