import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'esp_service.dart';
import 'fish.dart';
import 'pages/connect_page.dart';
import 'pages/control_page.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/sensors_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kSurface,
  ));
  await Future.wait([esp.init(), tank.load()]);
  runApp(const AquaApp());
}

class AquaApp extends StatelessWidget {
  const AquaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmmoniaSense',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: esp,
        builder: (_, __) =>
            esp.connected ? const AppShell() : const ConnectPage(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = esp.alerts.listen((msg) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF3A1820),
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: kBad),
              const SizedBox(width: 12),
              Expanded(child: Text(msg)),
            ],
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: kAccent,
            onPressed: () => setState(() => _index = 1),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          SensorsPage(),
          ControlPage(),
          HistoryPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: esp,
        builder: (_, __) {
          final n = esp.sensorErrors.length;
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.sensors_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.sensors_rounded),
                ),
                label: 'Sensors',
              ),
              const NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Control',
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Records',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          );
        },
      ),
    );
  }
}
