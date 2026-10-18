part of '../classic_levels.dart';

// Classic level 4. Coordinates use the 360 x 560 board.
const classicLevel04 = ClassicLevelDefinition(
  name: "Little wave",
  holes: [
    Hole(158, 450, target: 1),
    Hole(254, 366, target: 2),
    Hole(108, 408, target: 3),
    Hole(230, 282, target: 4),
    Hole(142, 324, target: 5),
    Hole(276, 198, target: 6),
    Hole(124, 240, target: 7),
    Hole(244, 114, target: 8),
    Hole(88, 156, target: 9),
    Hole(210, 64, target: 10),
    Hole(208, 204),
    Hole(152, 160),
    Hole(112, 80),
    Hole(152, 72),
    Hole(40, 214),
    Hole(324, 54),
  ],
  spiders: [],
  finaleTitle: "",
  finaleRule: "",
  hazards: [],
  firstHazardAfter: 3,
  hazardInterval: 9,
);
