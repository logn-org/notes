import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:logn_notes/main.dart'; // Assuming 'logn_notes' is your package name

void main() {
  testWidgets('App initializes and displays Login or Home Screen', (WidgetTester tester) async {
    // Set mock initial values for SharedPreferences before the test runs
    // Provide an empty map, or mock data if your ThemeNotifier needs it.
    SharedPreferences.setMockInitialValues({});

    // Get the SharedPreferences instance (it will use the mock values)
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame, passing the required prefs instance.
    // Use the actual MyApp widget from your main.dart
    await tester.pumpWidget(MyApp(prefs: prefs));

    // Wait for widgets to settle, especially StreamBuilder for auth state
    await tester.pumpAndSettle();

    // --- Test Update ---
    // The original counter test is likely placeholder code and won't work
    // with your actual app structure (which shows LoginScreen or HomeScreen).
    // Instead, you might test if either the LoginScreen or HomeScreen appears
    // based on the initial (mocked) auth state.

    // Example: Verify if the LoginScreen's Google Sign-In button is present
    // (This assumes the initial auth state is logged out)
    expect(find.text('Sign in with Google'), findsOneWidget);

    // Or, if you mock a logged-in state (more complex), you'd check for HomeScreen elements.
    // expect(find.text('Your Notes'), findsOneWidget); // Example check for HomeScreen AppBar title
  });
}
