import 'dart:math' as math;

import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Cell values: -1 empty, 0..5 colors, 7 stone (never pops, can drop).
/// Shot kinds: 0..5 colors, 8 bomb, 9 rainbow.
const int kEmpty = -1;
const int kStone = 7;
const int kBombShot = 8;
const int kRainbow = 9;
const int kCols = 10;
const double kD = 96;
const double kR = 48;
const double kRowH = 83.14; // kD * sqrt(3)/2
const double kLeft = 20;
const double kRight = 980;
const double kTop = 140;
const double kShooterX = 500;
const double kShooterY = 1440;
const double kDeadLine = 1290;

class BubbleLevel {
  final ArcadeMeta meta;
  final List<List<int>> rows;
  final int colors;
  final int descendEvery; // shots, 0 = never
  final bool specials;

  const BubbleLevel({
    required this.meta,
    required this.rows,
    required this.colors,
    required this.descendEvery,
    required this.specials,
  });
}

List<int> _row(SeededRandom r, int colors, int d, bool stones, List<int>? above) {
  final row = List<int>.filled(kCols, kEmpty);
  for (var c = 0; c < kCols; c++) {
    // Clusters: often repeat the color left or above.
    if (c > 0 && row[c - 1] >= 0 && row[c - 1] < 6 && r.chance(0.45)) {
      row[c] = row[c - 1];
    } else if (above != null && above[c] >= 0 && above[c] < 6 && r.chance(0.35)) {
      row[c] = above[c];
    } else {
      row[c] = r.nextInt(colors);
    }
    if (stones && r.chance(0.06)) row[c] = kStone;
  }
  return row;
}

BubbleLevel generateBubbleLevel(LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final r = SeededRandom(mixSeed([spec.seed, 14]));
  final d = spec.difficulty;
  final colors = (3 + d ~/ 3 + (spec.has('colors') ? 1 : 0)).clamp(3, 6);
  final n = (4 + d ~/ 2).clamp(4, 8);
  final rows = <List<int>>[];
  for (var i = 0; i < n; i++) {
    rows.add(_row(r, colors, d, spec.has('stone') && i > 0, rows.isEmpty ? null : rows.last));
  }
  var every = m.goal ? (10 - d ~/ 2).clamp(5, 10) : 8;
  if (spec.has('descend')) every -= 2;
  return BubbleLevel(
    meta: m,
    rows: rows,
    colors: colors,
    descendEvery: m.zen ? 0 : every,
    specials: spec.has('bomb') || spec.has('rainbow'),
  );
}

/// Hex grid helpers with a parity shift (inserting a top row flips parity).
class BubbleGrid {
  List<List<int>> rows;
  int shift;
  BubbleGrid(this.rows, this.shift);

  BubbleGrid copy() => BubbleGrid([for (final r in rows) [...r]], shift);

  bool odd(int r) => (r + shift).isOdd;
  int width(int r) => odd(r) ? kCols - 1 : kCols;

  double cx(int r, int c) => kLeft + kR + c * kD + (odd(r) ? kR : 0);
  double cy(int r, double top) => top + kR + r * kRowH;

  int at(int r, int c) => r < 0 || r >= rows.length || c < 0 || c >= width(r) ? kEmpty : rows[r][c];

  void set(int r, int c, int v) {
    while (rows.length <= r) {
      rows.add(List<int>.filled(kCols, kEmpty));
    }
    rows[r][c] = v;
  }

  List<(int, int)> neighbors(int r, int c) {
    final o = odd(r) ? 1 : 0;
    return [
      (r, c - 1),
      (r, c + 1),
      (r - 1, c - 1 + o),
      (r - 1, c + o),
      (r + 1, c - 1 + o),
      (r + 1, c + o),
    ].where((p) => p.$1 >= 0 && p.$2 >= 0 && p.$2 < width(p.$1)).toList();
  }

  int get count {
    var n = 0;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < width(r); c++) {
        if (rows[r][c] != kEmpty) n++;
      }
    }
    return n;
  }

  int lowestRow() {
    for (var r = rows.length - 1; r >= 0; r--) {
      for (var c = 0; c < width(r); c++) {
        if (rows[r][c] != kEmpty) return r;
      }
    }
    return -1;
  }

  Set<int> colorsLeft() {
    final s = <int>{};
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < width(r); c++) {
        final v = rows[r][c];
        if (v >= 0 && v < 6) s.add(v);
      }
    }
    return s;
  }

  /// Places [kind] at (r,c) and resolves pops and drops.
  (int popped, int dropped) resolve(int r, int c, int kind) {
    var popped = 0;
    if (kind == kBombShot) {
      set(r, c, kEmpty);
      for (final n in [...neighbors(r, c), for (final n in neighbors(r, c)) ...neighbors(n.$1, n.$2)]) {
        if (at(n.$1, n.$2) != kEmpty) {
          rows[n.$1][n.$2] = kEmpty;
          popped++;
        }
      }
    } else {
      var color = kind;
      if (kind == kRainbow) {
        // Takes the color of the largest neighbouring group.
        var best = -1, bestSize = 0;
        for (final n in neighbors(r, c)) {
          final v = at(n.$1, n.$2);
          if (v < 0 || v > 5) continue;
          final size = _group(n.$1, n.$2, v).length;
          if (size > bestSize) {
            bestSize = size;
            best = v;
          }
        }
        color = best < 0 ? 0 : best;
      }
      set(r, c, color);
      final g = _group(r, c, color);
      if (g.length >= 3) {
        for (final p in g) {
          rows[p.$1][p.$2] = kEmpty;
        }
        popped = g.length;
      }
    }
    final dropped = popped > 0 ? _dropFloating() : 0;
    while (rows.isNotEmpty && rows.last.every((v) => v == kEmpty)) {
      rows.removeLast();
    }
    return (popped, dropped);
  }

  List<(int, int)> _group(int r, int c, int color) {
    final seen = <int>{r * 16 + c};
    final out = [(r, c)];
    for (var i = 0; i < out.length; i++) {
      for (final n in neighbors(out[i].$1, out[i].$2)) {
        if (at(n.$1, n.$2) != color || !seen.add(n.$1 * 16 + n.$2)) continue;
        out.add(n);
      }
    }
    return out;
  }

  int _dropFloating() {
    if (rows.isEmpty) return 0;
    final seen = <int>{};
    final st = <(int, int)>[];
    for (var c = 0; c < width(0); c++) {
      if (rows[0][c] != kEmpty) {
        seen.add(c);
        st.add((0, c));
      }
    }
    while (st.isNotEmpty) {
      final p = st.removeLast();
      for (final n in neighbors(p.$1, p.$2)) {
        if (at(n.$1, n.$2) == kEmpty || !seen.add(n.$1 * 16 + n.$2)) continue;
        st.add(n);
      }
    }
    var dropped = 0;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < width(r); c++) {
        if (rows[r][c] != kEmpty && !seen.contains(r * 16 + c)) {
          rows[r][c] = kEmpty;
          dropped++;
        }
      }
    }
    return dropped;
  }
}

/// Result of tracing a shot.
class ShotPath {
  final List<(double, double)> points;
  final int row, col;
  final int banks;
  const ShotPath(this.points, this.row, this.col, this.banks);
}

/// Traces a shot from the shooter toward (ax, ay). Null if the aim is
/// too flat or no cell is free.
ShotPath? traceShot(BubbleGrid g, double top, double ax, double ay) {
  var dx = ax - kShooterX, dy = ay - kShooterY;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1 || dy > -0.15 * len) return null;
  dx /= len;
  dy /= len;
  var x = kShooterX, y = kShooterY;
  final pts = <(double, double)>[(x, y)];
  var banks = 0;
  for (var step = 0; step < 900; step++) {
    x += dx * 8;
    y += dy * 8;
    if (x < kLeft + kR) {
      x = kLeft + kR;
      dx = dx.abs();
      banks++;
      pts.add((x, y));
    } else if (x > kRight - kR) {
      x = kRight - kR;
      dx = -dx.abs();
      banks++;
      pts.add((x, y));
    }
    var stop = y <= top + kR;
    if (!stop) {
      final rr = ((y - top - kR) / kRowH).round();
      for (var r = math.max(0, rr - 1); r <= math.min(g.rows.length - 1, rr + 1) && !stop; r++) {
        for (var c = 0; c < g.width(r); c++) {
          if (g.rows[r][c] == kEmpty) continue;
          final ex = g.cx(r, c) - x, ey = g.cy(r, top) - y;
          if (ex * ex + ey * ey < (kD * 0.86) * (kD * 0.86)) {
            stop = true;
            break;
          }
        }
      }
    }
    if (stop) {
      final cell = _snap(g, top, x, y);
      if (cell == null) return null;
      pts.add((g.cx(cell.$1, cell.$2), g.cy(cell.$1, top)));
      return ShotPath(pts, cell.$1, cell.$2, banks);
    }
  }
  return null;
}

(int, int)? _snap(BubbleGrid g, double top, double x, double y) {
  (int, int)? best;
  var bd = 1e18;
  final rr = ((y - top - kR) / kRowH).round();
  for (var r = math.max(0, rr - 1); r <= rr + 1; r++) {
    for (var c = 0; c < g.width(r); c++) {
      if (g.at(r, c) != kEmpty) continue;
      // must touch the ceiling or a bubble
      final attached = r == 0 || g.neighbors(r, c).any((n) => g.at(n.$1, n.$2) != kEmpty);
      if (!attached) continue;
      final ex = g.cx(r, c) - x, ey = g.cy(r, top) - y;
      final dd = ex * ex + ey * ey;
      if (dd < bd) {
        bd = dd;
        best = (r, c);
      }
    }
  }
  return best;
}

class BubbleSim extends ArcadeSim {
  final BubbleLevel level;
  late BubbleGrid grid;
  int current = 0;
  int next = 0;
  int shots = 0;
  int popped = 0;
  int droppedTotal = 0;
  int bankShots = 0;
  int initialCount = 1;
  int stage = 1;
  ShotPath? flying;
  int flyKind = 0;
  double flyT = 0;
  double aimX = kShooterX, aimY = 600;
  int lastEvent = 0; // 1 pop, 2 stick, 3 drop

  BubbleSim(this.level) : super(level.meta) {
    grid = BubbleGrid([for (final r in level.rows) [...r]], 0);
    for (var r = 0; r < grid.rows.length; r++) {
      if (grid.odd(r)) grid.rows[r][kCols - 1] = kEmpty;
    }
    initialCount = math.max(1, grid.count);
    current = _draw();
    next = _draw();
  }

  double get top => kTop;

  int _draw() {
    if (level.specials && rng.chance(0.07)) {
      return meta.has('bomb') && (!meta.has('rainbow') || rng.chance(0.5)) ? kBombShot : kRainbow;
    }
    final left = grid.colorsLeft().toList()..sort();
    if (left.isEmpty) return rng.nextInt(level.colors);
    return left[rng.nextInt(left.length)];
  }

  /// Fires toward the aim point.
  bool fire(double ax, double ay) {
    if (flying != null || over) return false;
    final p = traceShot(grid, top, ax, ay);
    if (p == null) return false;
    flying = p;
    flyKind = current;
    flyT = 0;
    current = next;
    next = _draw();
    shots++;
    return true;
  }

  void swap() {
    if (flying != null) return;
    final t = current;
    current = next;
    next = t;
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (input.hasPointer && input.y < kShooterY - 40) {
      aimX = input.x;
      aimY = input.y;
    } else if (input.dirX != 0) {
      aimX = clampD(aimX + input.dirX * 12, 0, kWorldW);
    }
    if (input.swipe == 2) swap();
    if (flying == null) {
      final tapShooter = input.tap && input.hasPointer && input.y >= kShooterY - 40;
      if (tapShooter) {
        swap();
      } else if (input.tap && input.hasPointer || input.swipe == 0) {
        fire(aimX, aimY);
      }
      return;
    }
    flyT += 34;
    final p = flying!;
    // Advance along the polyline.
    var remaining = flyT;
    for (var i = 1; i < p.points.length; i++) {
      final a = p.points[i - 1], b = p.points[i];
      final seg = math.sqrt((b.$1 - a.$1) * (b.$1 - a.$1) + (b.$2 - a.$2) * (b.$2 - a.$2));
      if (remaining <= seg) return;
      remaining -= seg;
    }
    _land(p);
  }

  void _land(ShotPath p) {
    flying = null;
    if (p.banks > 0) bankShots++;
    final (pop, drop) = grid.resolve(p.row, p.col, flyKind);
    popped += pop;
    droppedTotal += drop;
    score += pop * 10 + drop * 20 + (pop > 0 && p.banks > 0 ? 15 : 0);
    lastEvent = drop > 0 ? 3 : (pop > 0 ? 1 : 2);
    if (grid.count == 0) {
      if (meta.goal) {
        win();
        return;
      }
      stage++;
      score += 300;
      final r = SeededRandom(mixSeed([meta.seed, stage]));
      grid = BubbleGrid([for (var i = 0; i < 5; i++) _row(r, level.colors, meta.difficulty, false, null)], 0);
    }
    if (level.descendEvery > 0 && pop == 0 && shots % level.descendEvery == 0) _descend();
    if (grid.lowestRow() >= 0 && grid.cy(grid.lowestRow(), top) + kR > kDeadLine) hit();
  }

  void _descend() {
    grid.rows.insert(0, _row(rng, level.colors, meta.difficulty, false, null));
    grid.shift++;
    for (var r = 0; r < grid.rows.length; r++) {
      if (grid.odd(r)) grid.rows[r][kCols - 1] = kEmpty;
    }
    grid.rows[0] = [for (final v in grid.rows[0]) v];
  }

  @override
  void onLifeLost() {
    // Clear the lowest rows so play can continue.
    while (grid.rows.isNotEmpty && grid.cy(grid.rows.length - 1, top) + kR > kDeadLine - 3 * kRowH) {
      grid.rows.removeLast();
    }
  }

  @override
  bool useBooster() {
    // Bomb bubble booster.
    if (over || flying != null) return false;
    current = kBombShot;
    return true;
  }

  @override
  double get progress => 1 - grid.count / initialCount;

  @override
  String get goalText => meta.goal ? '${grid.count}' : 'x$stage';

  @override
  Map<String, int> get stats => {'bubbles_popped': popped, 'bubbles_dropped': droppedTotal, 'bank_shots': bankShots};

  @override
  int get stars => lifeStars(this, 3);
}

/// Candidate aim points: along the top and both side walls.
final List<(double, double)> kAimPoints = [
  for (var x = 20.0; x <= 980; x += 24) (x, 0.0),
  for (var y = 300.0; y <= 1300; y += 40) (0.0, y),
  for (var y = 300.0; y <= 1300; y += 40) (1000.0, y),
];

/// Evaluates every aim and returns the best one (or null).
(double, double)? bestAim(BubbleSim s, int kind) {
  (double, double)? best;
  var bestScore = -1e9;
  for (final a in kAimPoints) {
    final p = traceShot(s.grid, s.top, a.$1, a.$2);
    if (p == null) continue;
    final g = s.grid.copy();
    var sameNeighbors = 0;
    for (final n in g.neighbors(p.row, p.col)) {
      if (g.at(n.$1, n.$2) == kind) sameNeighbors++;
    }
    final (pop, drop) = g.resolve(p.row, p.col, kind);
    final low = g.lowestRow();
    final danger = low >= 0 && g.cy(low, s.top) + kR > kDeadLine - kRowH ? 400 : 0;
    final v = pop * 10 + drop * 16 + sameNeighbors * 3 - p.row * 0.5 - danger - p.banks * 0.2;
    if (v > bestScore) {
      bestScore = v;
      best = a;
    }
  }
  return best;
}

ArcadeInput bubbleBot(ArcadeSim sim) {
  final s = sim as BubbleSim;
  if (s.flying != null || s.ticks % 6 != 0) return ArcadeInput.idle;
  // Consider swapping when the next bubble gives a better shot.
  final a = bestAim(s, s.current);
  if (a == null) return ArcadeInput.idle;
  return ArcadeInput(tap: true, down: true, x: a.$1, y: a.$2);
}
