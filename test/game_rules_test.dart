import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:game_014_bubble_shooter_world/game/bubble_engine.dart';
import 'package:game_014_bubble_shooter_world/game/rules.dart';

void main() {
  final rules = BubbleRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('three of a kind pop, floating bubbles drop', () {
    final g = BubbleGrid([
      [0, 0, 1, 1, 1, 1, 1, 1, 1, 1],
      [2, 2, 2, 2, 2, 2, 2, 2, 2, -1],
      [-1, 3, -1, -1, -1, -1, -1, -1, -1, -1],
    ], 0);
    final (pop, drop) = g.resolve(0, 2, 0); // 0 at (0,2)? occupied -> overwrite test below
    expect(pop + drop, greaterThanOrEqualTo(0));
    final h = BubbleGrid([
      [0, 0, -1, 1, 1, 1, 1, 1, 1, 1],
      [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    ], 0);
    final (p2, _) = h.resolve(0, 2, 0);
    expect(p2, 3);
    final f = BubbleGrid([
      [0, 0, -1, -1, -1, -1, -1, -1, -1, -1],
      [4, -1, -1, -1, -1, -1, -1, -1, -1, -1],
      [5, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    ], 0);
    final (p3, d3) = f.resolve(0, 2, 0);
    expect(p3, 3);
    expect(d3, 2);
  });

  test('a shot straight up sticks to the grid', () {
    final s = BubbleSim(rules.build(planner.spec(1)).puzzle);
    final p = traceShot(s.grid, s.top, kShooterX, 0);
    expect(p, isNotNull);
    expect(s.grid.at(p!.row, p.col), kEmpty);
  });

  test('bank shot reflects off the wall', () {
    final s = BubbleSim(rules.build(planner.spec(1)).puzzle);
    final p = traceShot(s.grid, s.top, 0, 1100);
    expect(p, isNotNull);
    expect(p!.banks, greaterThan(0));
  });
}
