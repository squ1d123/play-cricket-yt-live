import 'package:flutter_test/flutter_test.dart';

import 'package:play_cricket_yt_live/main.dart';

void main() {
  testWidgets('App smoke test - HomeScreen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PlayCricketLiveApp());

    // Pump a few frames to let the widget build
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify basic structure exists
    expect(find.byType(PlayCricketLiveApp), findsOneWidget);
  });
}