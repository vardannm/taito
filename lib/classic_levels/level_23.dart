part of '../classic_levels.dart';

// Classic level 23. Coordinates use the 360 x 560 board.
const classicLevel23 = ClassicLevelDefinition(
  name: "Chicane",
  holes: [
    Hole(60, 210, target: 1),
    Hole(190, 390, target: 2),
    Hole(260, 370, target: 3),
    Hole(50, 120, target: 4),
    Hole(190, 310, target: 5),
    Hole(240, 190, target: 6),
    Hole(170, 210, target: 7),
    Hole(100, 160, target: 8, motion: HoleMotion(path: HazardMotion.horizontal, radiusX: 40, radiusY: 25, period: 4, phase: 0)),
    Hole(120, 70, target: 9),
    Hole(200, 70, target: 10),
  ],
  spiders: [
  ],
  finaleTitle: "",
  finaleRule: "",
  hazards: [
    ClassicHazardWave(
      kind: HazardKind.laser,
      motion: HazardMotion.horizontal,
      orientation: LaserOrientation.vertical,
      radiusX: 150,
      radiusY: 25,
      period: 4,
      phase: 0,
      dashLength: 60,
      dashGap: 39.8,
      dashSpeed: 5,
      stopAboveStart: true,
      warningSeconds: 2.4,
      liveSeconds: 999,
      positions: [
        ClassicHazardPosition(target: 1, x: 180, y: 250),
      ],
    ),
  ],
  firstHazardAfter: 1,
  hazardInterval: 9,
);
