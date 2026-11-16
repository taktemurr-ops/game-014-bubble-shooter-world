import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const BubbleShooterWorld());

class BubbleShooterWorld extends StatelessWidget {
  const BubbleShooterWorld({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Bubble Shooter World',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const BubbleBoard(),
  );
}

class BubbleBoard extends StatefulWidget {
  const BubbleBoard({super.key});
  @override
  State<BubbleBoard> createState() => _BubbleBoardState();
}

class _BubbleBoardState extends State<BubbleBoard> {
  static const cols = 8;
  static const rows = 10;
  final random = Random();
  final colors = <Color>[Colors.redAccent, Colors.lightBlueAccent,
    Colors.greenAccent, Colors.amber, Colors.purpleAccent];
  late List<List<int?>> cells;
  int next = 0;
  int score = 0;
  int moves = 0;
  int bestScore = 0;
  bool get won => cells.every((row) => row.every((cell) => cell == null));
  bool get lost => cells.last.any((cell) => cell != null);
  bool get finished => won || lost;

  _BubbleBoardState() { resetData(); }

  void resetData() {
    cells = List.generate(rows, (r) => List.generate(cols,
      (c) => r < 4 ? Random(r * 100 + c).nextInt(5) : null));
    next = 0; score = 0; moves = 0;
  }

  List<(int,int)> neighbors(int r, int c) => [
    (r, c - 1), (r, c + 1), (r - 1, c), (r + 1, c),
    (r - 1, c + (r.isOdd ? 1 : -1)),
    (r + 1, c + (r.isOdd ? 1 : -1)),
  ].where((p) => p.$1 >= 0 && p.$1 < rows && p.$2 >= 0 && p.$2 < cols).toList();

  void shoot(int r, int c) {
    if (finished || cells[r][c] != null) return;
    if (r != 0 && !neighbors(r,c).any((p) => cells[p.$1][p.$2] != null)) return;
    setState(() {
      cells[r][c] = next;
      moves++;
      final seen = <(int,int)>{(r,c)};
      final queue = <(int,int)>[(r,c)];
      for (var i=0; i<queue.length; i++) {
        for(final p in neighbors(queue[i].$1,queue[i].$2)) {
          if(!seen.contains(p) && cells[p.$1][p.$2] == next) {
            seen.add(p); queue.add(p);
          }
        }
      }
      if(seen.length >= 3) {
        for(final p in seen) {cells[p.$1][p.$2] = null;}
        score += seen.length * 100;
        // Remove clusters not connected to top row.
        final anchored = <(int,int)>{};
        final frontier = <(int,int)>[];
        for(var col=0; col<cols; col++){
          if(cells[0][col] != null){anchored.add((0,col));frontier.add((0,col));}
        }
        for(var i=0;i<frontier.length;i++){
          for(final p in neighbors(frontier[i].$1,frontier[i].$2)){
            if(cells[p.$1][p.$2] != null && anchored.add(p)) frontier.add(p);
          }
        }
        for(var y=0;y<rows;y++)for(var x=0;x<cols;x++){
          if(cells[y][x] != null && !anchored.contains((y,x))){
            cells[y][x]=null;score+=50;
          }
        }
      }
      if (score > bestScore) bestScore = score;
      next = random.nextInt(colors.length);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bubble Shooter World')),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child:
        Text('Score: $score   Shots: $moves   Next:', style: const TextStyle(fontSize:18))),
      Container(width:34,height:34, decoration:BoxDecoration(color:colors[next],shape:BoxShape.circle)),
      Text('Best score: $bestScore'),
      if (finished) Text(won ? 'Level cleared!' : 'Game over!',
        key: const ValueKey('bubble-result')),

      const SizedBox(height:20),
      Expanded(child: LayoutBuilder(builder:(context,limits) {
        final diameter = min((limits.maxWidth - 20) / (cols + 0.5),
          (limits.maxHeight - 20) / (rows * 0.88 + 1));
        return Center(child: Column(mainAxisSize:MainAxisSize.min,
          children:List.generate(rows,(r)=>Transform.translate(
            offset:Offset(r.isOdd ? diameter/2 : 0,0),
            child:Row(mainAxisSize:MainAxisSize.min,children:
              List.generate(cols,(c)=>GestureDetector(
                onTap:()=>shoot(r,c),
                child:Container(width:diameter,height:diameter*0.88,
                  padding:const EdgeInsets.all(2),
                  child:DecoratedBox(decoration:BoxDecoration(
                    color: cells[r][c] == null ? Colors.white10 : colors[cells[r][c]!],
                    shape:BoxShape.circle)))))))));
      })),
      const Text('Tap an empty slot attached to bubbles. Match three to pop.'),
      Padding(padding:const EdgeInsets.all(12),child:
        FilledButton(onPressed:()=>setState(resetData),child:const Text('New Game'))),
    ])),
  );
}
