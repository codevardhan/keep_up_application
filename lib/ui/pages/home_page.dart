// lib/ui/pages/home_page.dart
import 'package:flutter/material.dart';
import '../../../core/app_state.dart';
import '../../../router.dart';
import '../theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = InheritedAppState.of(context);
    final goalLabel = state.activeGoal?.label ?? 'Find your focus';
    const weeklyTarget = 3;
    final weeklyDone = 0;

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBg),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + tiny gear
                Text(
                  _prettyDate(DateTime.now()),
                  style: AppText.small.copyWith(color: AppColors.neutral600),
                ),
                const SizedBox(height: 12),

                // Goal card
                _GoalCard(
                  title: 'Current goal',
                  goal: goalLabel,
                  onEdit: () =>
                      Navigator.pushNamed(context, AppRoutes.onboarding),
                ),
                const SizedBox(height: 14),

                // Connections progress
                _ConnectionsCard(done: weeklyDone, target: weeklyTarget),
                const SizedBox(height: 18),

                // Next steps header
                Row(
                  children: [
                    Text('Next steps', style: AppText.h2),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.suggestions),
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Quick entry points
                _NextTile(
                  title: 'See suggestions',
                  subtitle: '2–3 people to reach out to',
                  leading: _CircleIcon(
                    icon: Icons.auto_awesome,
                    bg: AppColors.purple100,
                    fg: AppColors.purple600,
                  ),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.suggestions),
                ),
                const SizedBox(height: 10),
                _NextTile(
                  title: 'Manage circles',
                  subtitle: 'Members & reminder cadence',
                  leading: _CircleIcon(
                    icon: Icons.people_alt_outlined,
                    bg: AppColors.teal100,
                    fg: AppColors.teal600,
                  ),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.circles),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _prettyDate(DateTime d) {
    // e.g., Friday, November 14
    final wd = _wd[d.weekday]!;
    final month = _mo[d.month]!;
    return '$wd, $month ${d.day.toString().padLeft(2, '0')}';
  }
}

class _GoalCard extends StatelessWidget {
  final String title;
  final String goal;
  final VoidCallback onEdit;

  const _GoalCard({
    required this.title,
    required this.goal,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
      decoration: BoxDecoration(
        gradient: AppGradients.goalCard,
        borderRadius: BorderRadius.circular(AppRadius.card + 2),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title + edit
          Row(
            children: [
              Row(
                children: const [
                  Icon(Icons.work_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Current goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: Colors.white.withOpacity(.35)),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            goal,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionsCard extends StatelessWidget {
  final int done;
  final int target;
  const _ConnectionsCard({required this.done, required this.target});

  @override
  Widget build(BuildContext context) {
    final pct = (target == 0) ? 0.0 : (done / target).clamp(0.0, 1.0);
    final pctText = '${(pct * 100).round()}%';

    return Container(
      decoration: AppDecor.card(color: AppColors.white),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          // left text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connections this week', style: AppText.h2),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$done',
                      style: const TextStyle(
                        color: AppColors.teal600,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                      ),
                    ),
                    Text(
                      '/$target',
                      style: AppText.body.copyWith(
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Small steps count. You're doing great.",
                  style: AppText.small,
                ),
              ],
            ),
          ),

          // progress ring
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 6,
                  color: AppColors.teal500,
                  backgroundColor: AppColors.neutral200,
                ),
                Text(
                  pctText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;

  const _NextTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecor.card(),
      child: ListTile(
        leading: leading,
        title: Text(title, style: AppText.h2),
        subtitle: Text(subtitle, style: AppText.body),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _CircleIcon({required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}

// weekday/month names
const _wd = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

const _mo = {
  1: 'January',
  2: 'February',
  3: 'March',
  4: 'April',
  5: 'May',
  6: 'June',
  7: 'July',
  8: 'August',
  9: 'September',
  10: 'October',
  11: 'November',
  12: 'December',
};
