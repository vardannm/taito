part of '../classic_levels.dart';

// Classic level 2. Coordinates use the 360 x 560 board.
const classicLevel02 = ClassicLevelDefinition(
  name: "Gentle bend",
  holes: [
    Hole(180, 450, target: 1),
    Hole(260, 366, target: 2),
    Hole(138, 408, target: 3),
    Hole(238, 282, target: 4),
    Hole(112, 324, target: 5),
    Hole(222, 198, target: 6),
    Hole(94, 240, target: 7),
    Hole(246, 114, target: 8),
    Hole(142, 156, target: 9),
    Hole(224, 72, target: 10),
    Hole(253, 432),
    Hole(293, 432),
    Hole(285, 212),
    Hole(293, 168),
  ],
  spiders: [],
  finaleTitle: "",
  finaleRule: "",
  hazards: [],
  firstHazardAfter: 3,
  hazardInterval: 9,
);
