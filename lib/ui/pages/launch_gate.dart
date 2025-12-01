import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../router.dart';

class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});
  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = InheritedAppState.of(context);
    // Defer navigation to the next frame to avoid build-time nav
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = state.onboardingSeen
          ? AppRoutes.home
          : AppRoutes.onboarding;
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
