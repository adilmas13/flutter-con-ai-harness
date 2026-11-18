import 'package:day_planner/agent/recordings.dart';
import 'package:day_planner/data/schedule.dart';
import 'package:day_planner/stores/app_store.dart';
import 'package:day_planner/stores/chat_items.dart';
import 'package:day_planner/ui/chat_cards.dart';
import 'package:day_planner/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long pasted message fits its bubble', (tester) async {
    final schedule = await Schedule.load();
    final paste = await rootBundle.loadString('assets/schedule_paste.txt');
    final store = AppStore(schedule, RecordingStore());
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    for (final item in [
      UserText('Plan my day. Here’s the schedule:\n\n$paste'),
      UserText('Plan my day as a short list.', pastedLines: 46),
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ChatCard(store: store, index: 0, item: item),
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    }
  });
}
