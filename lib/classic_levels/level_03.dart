part of '../classic_levels.dart';

// Classic level 3. Coordinates use the 360 x 560 board.
const classicLevel03 = ClassicLevelDefinition(
  name: "Wide valley",
  holes: [
    Hole(204, 450, target: 1),
    Hole(98, 366, target: 2),
    Hole(244, 408, target: 3),
    Hole(132, 282, target: 4),
    Hole(266, 324, target: 5),
    Hole(104, 198, target: 6),
    Hole(240, 240, target: 7),
    Hole(116, 114, target: 8),
    Hole(274, 156, target: 9),
    Hole(178, 64, target: 10),
    Hole(156, 388),
    Hole(204, 344),
    Hole(66, 288),
    Hole(204, 168),
    Hole(294, 68),
  ],
  spiders: [],
  finaleTitle: "",
  finaleRule: "",
  hazards: [],
  firstHazardAfter: 3,
  hazardInterval: 9,
);
