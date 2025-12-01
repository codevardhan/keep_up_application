import 'package:flutter/material.dart';
import 'router.dart';
import 'core/app_state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/notification_service.dart';
import 'services/daily_scheduler.dart';
import 'services/app_lifecycle_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env/.env');
  await NotificationService.init();
  await NotificationService.requestPermissions();

  runApp(const KeepUpApp());
}

class KeepUpApp extends StatefulWidget {
  const KeepUpApp({super.key});

  @override
  State<KeepUpApp> createState() => _KeepUpAppState();
}

class _KeepUpAppState extends State<KeepUpApp> {
  final appState = AppState(); // simple in-memory store
  late final AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await appState.init();

      await DailyScheduler.maybeRunToday(appState, k: 1);

      _lifecycleObserver = AppLifecycleObserver(appState)..start();
    });
  }

  @override
  void dispose() {
    // Stop listening to lifecycle changes.
    _lifecycleObserver.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InheritedAppState(
      state: appState,
      child: MaterialApp(
        title: 'KeepUp MVP',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.onboarding,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
