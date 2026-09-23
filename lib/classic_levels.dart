import 'game.dart';
import 'hazards.dart';
import 'spiders.dart';

part 'classic_levels/level_01.dart';
part 'classic_levels/level_02.dart';
part 'classic_levels/level_03.dart';
part 'classic_levels/level_04.dart';
part 'classic_levels/level_05.dart';
part 'classic_levels/level_06.dart';
part 'classic_levels/level_07.dart';
part 'classic_levels/level_08.dart';
part 'classic_levels/level_09.dart';
part 'classic_levels/level_10.dart';
part 'classic_levels/level_11.dart';
part 'classic_levels/level_12.dart';
part 'classic_levels/level_13.dart';
part 'classic_levels/level_14.dart';
part 'classic_levels/level_15.dart';
part 'classic_levels/level_16.dart';
part 'classic_levels/level_17.dart';
part 'classic_levels/level_18.dart';
part 'classic_levels/level_19.dart';
part 'classic_levels/level_20.dart';
part 'classic_levels/level_21.dart';
part 'classic_levels/level_22.dart';
part 'classic_levels/level_23.dart';
part 'classic_levels/level_24.dart';
part 'classic_levels/level_25.dart';
part 'classic_levels/level_26.dart';
part 'classic_levels/level_27.dart';
part 'classic_levels/level_28.dart';
part 'classic_levels/level_29.dart';
part 'classic_levels/level_30.dart';
part 'classic_levels/level_31.dart';
part 'classic_levels/level_32.dart';
part 'classic_levels/level_33.dart';
part 'classic_levels/level_34.dart';
part 'classic_levels/level_35.dart';
part 'classic_levels/level_36.dart';
part 'classic_levels/level_37.dart';
part 'classic_levels/level_38.dart';
part 'classic_levels/level_39.dart';
part 'classic_levels/level_40.dart';
part 'classic_levels/level_41.dart';
part 'classic_levels/level_42.dart';
part 'classic_levels/level_43.dart';
part 'classic_levels/level_44.dart';
part 'classic_levels/level_45.dart';
part 'classic_levels/level_46.dart';
part 'classic_levels/level_47.dart';
part 'classic_levels/level_48.dart';
part 'classic_levels/level_49.dart';
part 'classic_levels/level_50.dart';
part 'classic_levels/level_51.dart';
part 'classic_levels/level_52.dart';
part 'classic_levels/level_53.dart';
part 'classic_levels/level_54.dart';
part 'classic_levels/level_55.dart';
part 'classic_levels/level_56.dart';
part 'classic_levels/level_57.dart';
part 'classic_levels/level_58.dart';
part 'classic_levels/level_59.dart';
part 'classic_levels/level_60.dart';
part 'classic_levels/level_61.dart';
part 'classic_levels/level_62.dart';
part 'classic_levels/level_63.dart';
part 'classic_levels/level_64.dart';
part 'classic_levels/level_65.dart';
part 'classic_levels/level_66.dart';
part 'classic_levels/level_67.dart';
part 'classic_levels/level_68.dart';
part 'classic_levels/level_69.dart';
part 'classic_levels/level_70.dart';
part 'classic_levels/level_71.dart';
part 'classic_levels/level_72.dart';
part 'classic_levels/level_73.dart';
part 'classic_levels/level_74.dart';
part 'classic_levels/level_75.dart';
part 'classic_levels/level_76.dart';
part 'classic_levels/level_77.dart';
part 'classic_levels/level_78.dart';
part 'classic_levels/level_79.dart';
part 'classic_levels/level_80.dart';

/// A hand-editable Classic level; holes without a target number are traps.
class ClassicLevelDefinition {
  const ClassicLevelDefinition({
    required this.name,
    required this.holes,
    this.spiders = const [],
    this.hazards = const [],
    this.finaleTitle = '',
    this.finaleRule = '',
    this.firstHazardAfter = 3,
    this.hazardInterval = 9,
  });
  final String name;
  final List<Hole> holes;
  final List<ClassicSpiderPlacement> spiders;
  final List<ClassicHazardWave> hazards;
  final String finaleTitle, finaleRule;
  final double firstHazardAfter, hazardInterval;
}

/// The fixed patrol center and behavior of one spider.
class ClassicSpiderPlacement {
  const ClassicSpiderPlacement({
    required this.x,
    required this.y,
    required this.zoneRadius,
    required this.phase,
    required this.chaseSpeed,
    required this.bodyRadius,
  });
  final double x, y, zoneRadius, phase, chaseSpeed, bodyRadius;

  BoardSpider create() => BoardSpider(
    x,
    y,
    zoneRadius,
    phase: phase,
    chaseSpeed: chaseSpeed,
    bodyRadius: bodyRadius,
  );
}

/// Waves repeat in file order; positions are selected for the current target.
class ClassicHazardWave {
  const ClassicHazardWave({
    required this.kind,
    required this.warningSeconds,
    required this.liveSeconds,
    required this.positions,
    this.motion = HazardMotion.legacy,
    this.orientation = LaserOrientation.vertical,
    this.radiusX = 40,
    this.radiusY = 25,
    this.period = 4,
    this.phase = 0,
  });
  final HazardKind kind;
  final double warningSeconds, liveSeconds;
  final List<ClassicHazardPosition> positions;
  final HazardMotion motion;
  final LaserOrientation orientation;
  final double radiusX, radiusY, period, phase;
}

class ClassicHazardPosition {
  const ClassicHazardPosition({
    required this.target,
    required this.x,
    required this.y,
  });
  final int target;
  final double x, y;
}

/// Permanent level order: keep these IDs stable for saved progress.
const classicLevelDefinitions = [
  classicLevel01,
  classicLevel02,
  classicLevel03,
  classicLevel04,
  classicLevel05,
  classicLevel06,
  classicLevel07,
  classicLevel08,
  classicLevel09,
  classicLevel10,
  classicLevel11,
  classicLevel12,
  classicLevel13,
  classicLevel14,
  classicLevel15,
  classicLevel16,
  classicLevel17,
  classicLevel18,
  classicLevel19,
  classicLevel20,
  classicLevel21,
  classicLevel22,
  classicLevel23,
  classicLevel24,
  classicLevel25,
  classicLevel26,
  classicLevel27,
  classicLevel28,
  classicLevel29,
  classicLevel30,
  classicLevel31,
  classicLevel32,
  classicLevel33,
  classicLevel34,
  classicLevel35,
  classicLevel36,
  classicLevel37,
  classicLevel38,
  classicLevel39,
  classicLevel40,
  classicLevel41,
  classicLevel42,
  classicLevel43,
  classicLevel44,
  classicLevel45,
  classicLevel46,
  classicLevel47,
  classicLevel48,
  classicLevel49,
  classicLevel50,
  classicLevel51,
  classicLevel52,
  classicLevel53,
  classicLevel54,
  classicLevel55,
  classicLevel56,
  classicLevel57,
  classicLevel58,
  classicLevel59,
  classicLevel60,
  classicLevel61,
  classicLevel62,
  classicLevel63,
  classicLevel64,
  classicLevel65,
  classicLevel66,
  classicLevel67,
  classicLevel68,
  classicLevel69,
  classicLevel70,
  classicLevel71,
  classicLevel72,
  classicLevel73,
  classicLevel74,
  classicLevel75,
  classicLevel76,
  classicLevel77,
  classicLevel78,
  classicLevel79,
  classicLevel80,
];
