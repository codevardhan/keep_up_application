import 'package:flutter/widgets.dart';
import '../core/app_state.dart';
import 'daily_scheduler.dart';

/// Triggers daily suggestions when app comes to foreground.
class AppLifecycleObserver with WidgetsBindingObserver {
  final AppState state;
  AppLifecycleObserver(this.state);

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      // Fire and forget; suggestions show/schedule in background.
      DailyScheduler.maybeRunToday(state, k: 1);
    }
  }
}
