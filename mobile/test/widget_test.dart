import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stepup_hub_mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen when logged out', (WidgetTester tester) async {
    // AuthState.bootstrap() reads a token via SharedPreferences; fake an empty store so it
    // resolves instead of hitting a real platform channel.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const StepUpHubApp());
    // Don't pumpAndSettle here: the initial loading screen's CircularProgressIndicator animates
    // forever, so settle on a bounded number of frames instead while bootstrap() resolves.
    for (var i = 0; i < 10 && find.text('Welcome back').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
