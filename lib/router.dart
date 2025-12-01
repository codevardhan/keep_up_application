import 'package:flutter/material.dart';
import 'ui/pages/onboarding_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/suggestions_page.dart';
import 'ui/pages/compose_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/circles_page.dart';
import 'ui/pages/circle_detail_page.dart';
import 'ui/pages/contact_edit_page.dart';
import 'ui/pages/launch_gate.dart';

class AppRoutes {
  static const onboarding = '/';
  static const launch = '/launch';
  static const home = '/home';
  static const suggestions = '/suggestions';
  static const compose = '/compose';
  static const settings = '/settings';
  static const circles = '/circles';
  static const circleDetail = '/circle';
  static const contactEdit = '/contact';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case AppRoutes.launch:
        return MaterialPageRoute(builder: (_) => const LaunchGate());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case AppRoutes.suggestions:
        return MaterialPageRoute(builder: (_) => const SuggestionsPage());
      case AppRoutes.compose:
        final args = settings.arguments as Map<String, dynamic>?;
        final contactId = args?['contactId'] as String?;
        return MaterialPageRoute(
          builder: (_) => ComposePage(contactId: contactId),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case AppRoutes.circles:
        return MaterialPageRoute(builder: (_) => const CirclesPage());
      case AppRoutes.circleDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final circleId = args?['circleId'] as String;
        return MaterialPageRoute(
          builder: (_) => CircleDetailPage(circleId: circleId),
        );
      case AppRoutes.contactEdit:
        final args = settings.arguments as Map?;
        final id = args?['contactId'] as String;
        return MaterialPageRoute(
          builder: (_) => ContactEditPage(contactId: id),
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
