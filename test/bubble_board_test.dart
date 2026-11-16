import 'package:flutter_test/flutter_test.dart';
import 'package:game_014_bubble_shooter_world/main.dart';

void main() {
  testWidgets('board shows new game and best score', (tester) async {
    await tester.pumpWidget(const BubbleShooterWorld());
    expect(find.text('New Game'), findsOneWidget);
    expect(find.text('Best score: 0'), findsOneWidget);
    expect(find.textContaining('Score: 0'), findsOneWidget);
  });

  testWidgets('new game resets the score display', (tester) async {
    await tester.pumpWidget(const BubbleShooterWorld());
    await tester.tap(find.text('New Game'));
    await tester.pump();
    expect(find.textContaining('Score: 0'), findsOneWidget);
  });
}
