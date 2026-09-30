import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'models/goal.dart';

import 'theme.dart';
import 'screens/today_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Goal.firstWeekday = _regionFirstWeekday();
  runApp(const GoalStatApp());
}

/// First day of the week for the device's region, e.g. Sunday for en_US and
/// Monday for en_GB or de.
int _regionFirstWeekday() {
  final symbols = dateTimeSymbolMap();
  final locale = Intl.verifiedLocale(
      WidgetsBinding.instance.platformDispatcher.locale.toString(),
      symbols.containsKey,
      onFailure: (_) => 'en_US')!;
  // intl counts from 0 = Monday; DateTime counts from 1 = Monday.
  return symbols[locale]!.FIRSTDAYOFWEEK + 1;
}

class GoalStatApp extends StatelessWidget {
  const GoalStatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoalStat',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final _todayKey = GlobalKey<TodayScreenState>();
  final _dashKey = GlobalKey<DashboardScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  void _onSaved() {
    if (_tab == 1) _dashKey.currentState?.refresh();
  }

  void _onGoalsChanged() {
    _todayKey.currentState?.refresh();
    _dashKey.currentState?.refresh();
    _historyKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(key: _todayKey, onSaved: _onSaved),
          DashboardScreen(key: _dashKey),
          HistoryScreen(key: _historyKey),
          SettingsScreen(onGoalsChanged: _onGoalsChanged),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 0) _todayKey.currentState?.checkDayRollover();
          if (i == 1) _dashKey.currentState?.refresh();
          if (i == 2) _historyKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
