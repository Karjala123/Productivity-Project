// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:productanalytics/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProductivityApp());

    // Verify that our splash screen text is present.
    expect(find.text('ProductivityAI'), findsOneWidget);
    expect(find.text('Your AI Productivity Coach'), findsOneWidget);

    // Advance the virtual clock by 2 seconds to let the onboarding timer complete
    await tester.pump(const Duration(seconds: 2));
  });
}
