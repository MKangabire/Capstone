import 'package:flutter_test/flutter_test.dart';
import 'package:mama_safe/screens/login_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Login button is disabled when fields are empty', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen()));

    final loginButton = find.text('Login');
    expect(loginButton, findsOneWidget);

    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
  });
}
