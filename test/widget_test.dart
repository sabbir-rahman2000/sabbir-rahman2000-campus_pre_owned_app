import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_reuse_flutter/main.dart';
import 'package:campus_reuse_flutter/screens/splash_screen.dart';
import 'package:campus_reuse_flutter/screens/auth/login_screen.dart';
import 'package:campus_reuse_flutter/screens/home/home_screen.dart';
import 'package:campus_reuse_flutter/screens/product/sell_screen.dart';
import 'package:campus_reuse_flutter/screens/profile/profile_screen.dart';
import 'package:campus_reuse_flutter/widgets/logo_widget.dart';

void main() {
  group('Campus Reuse App Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      await tester.pumpWidget(const CampusReuseApp());
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('Splash screen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );

      expect(find.byType(LogoWidget), findsOneWidget);
    });

    testWidgets('Login screen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
    });

    testWidgets('Home screen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );

      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Featured Listings'), findsOneWidget);
    });

    testWidgets('Sell screen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SellScreen()),
      );

      expect(find.text('Sell Item'), findsOneWidget);
    });

    testWidgets('Profile screen renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProfileScreen()),
      );

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Logo widget displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LogoWidget(),
          ),
        ),
      );

      expect(find.text('Campus Pre-owned'), findsOneWidget);
    });

    testWidgets('Login form validation works for empty fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });
}
