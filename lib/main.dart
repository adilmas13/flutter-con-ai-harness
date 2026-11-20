import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'dev/autopilot.dart';
import 'data/schedule.dart';
import 'stores/app_store.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final schedule = await Schedule.load();
  final pasteText = await rootBundle.loadString('assets/schedule_paste.txt');
  final store = AppStore(schedule, scheduleText: pasteText);
  runApp(DayPlannerApp(store: store));
  if (autopilot) {
    WidgetsBinding.instance.addPostFrameCallback((_) => runAutopilot(store));
  }
}

class DayPlannerApp extends StatelessWidget {
  const DayPlannerApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Day Planner',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: RepaintBoundary(key: screenKey, child: HomePage(store: store)),
      );
}
