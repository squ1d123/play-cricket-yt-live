import 'package:flutter_test/flutter_test.dart';

import 'package:play_cricket_yt_live/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PlayCricketLiveApp());
    expect(find.text('Play Cricket Live'), findsOneWidget);
  });
}