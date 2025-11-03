import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mama_safe/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Tests', () {
    testWidgets('App startup performance', (tester) async {
      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      print('⏱️  App startup: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Under 3 seconds
    });

    testWidgets('Prediction flow performance', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      
      final stopwatch = Stopwatch()..start();
      
      // Navigate to prediction screen (adjust based on your app)
      await tester.tap(find.text('New Prediction')); // Example
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      print('⏱️  Navigation time: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Under 1 second
    });
  });
}