
import 'package:flutter/material.dart';
import 'router.dart';
import 'core/app_state.dart';

void main() {
  runApp(const KeepUpApp());
}

class KeepUpApp extends StatefulWidget {
  const KeepUpApp({super.key});

  @override
  State<KeepUpApp> createState() => _KeepUpAppState();
}

class _KeepUpAppState extends State<KeepUpApp> {
  final appState = AppState(); // simple in-memory store

  @override
  void initState() {
    super.initState();
    appState.init(); // load saved contacts at app launch
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

