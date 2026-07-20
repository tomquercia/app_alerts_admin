import 'package:flutter/material.dart';

import 'src/state/admin_controller.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/home_page.dart';

void main() {
  runApp(const AppAlertsAdminApp());
}

/// Root of the app_alerts admin portal.
class AppAlertsAdminApp extends StatefulWidget {
  /// Creates the app.
  const AppAlertsAdminApp({super.key});

  @override
  State<AppAlertsAdminApp> createState() => _AppAlertsAdminAppState();
}

class _AppAlertsAdminAppState extends State<AppAlertsAdminApp> {
  late final AdminController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app_alerts admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, _) {
          if (!_controller.isLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomePage(controller: _controller);
        },
      ),
    );
  }
}
