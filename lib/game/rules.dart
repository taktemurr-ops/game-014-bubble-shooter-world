import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'bubble_engine.dart';

class BubbleRules extends ArcadeRules<BubbleLevel> {
  @override
  String get gameId => 'game-014-bubble-shooter-world';

  @override
  List<String> get optionalMechanics => const ['bomb', 'rainbow', 'stone', 'descend', 'colors'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('bubbles_popped', 'Patlayan balon', 'Bubbles popped', scale: 200),
        GameStat('bubbles_dropped', 'Düşen balon', 'Bubbles dropped', scale: 50),
        GameStat('bank_shots', 'Duvar atışı', 'Bank shots', scale: 10),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('bubbles_popped', 'bubbles_popped', [66, 133, 200]),
        MissionTemplate('bubbles_dropped', 'bubbles_dropped', [16, 33, 50]),
      ];

  @override
  BubbleLevel generate(LevelSpec spec) => generateBubbleLevel(spec);

  @override
  ArcadeMeta metaOf(BubbleLevel l) => l.meta;

  @override
  ArcadeSim createSim(BubbleLevel l) => BubbleSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => bubbleBot(sim);
}

ArcadeRules createRules() => BubbleRules();
