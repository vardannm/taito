part of '../classic_levels.dart';

// Classic level 7. Coordinates use the 360 x 560 board.
const classicLevel07 = ClassicLevelDefinition(
  name: "Right bank",
  holes: [
    Hole(212, 450, target: 1),
    Hole(116, 366, target: 2),
    Hole(260, 408, target: 3),
    Hole(142, 198, target: 4),
    Hole(278, 282, target: 5),
    Hole(122, 114, target: 6),
    Hole(234, 324, target: 7),
    Hole(90, 240, target: 8),
    Hole(266, 72, target: 9),
    Hole(154, 156, target: 10),
    Hole(294, 332),
    Hole(156, 300),
    Hole(66, 288),
    Hole(204, 256),
    Hole(294, 156),
    Hole(66, 112),
    Hole(204, 80),
    Hole(40, 334),
    Hole(244, 174),
  ],
  spiders: [],
  finaleTitle: "",
  finaleRule: "",
  hazards: [],
  firstHazardAfter: 3,
  hazardInterval: 9,
);
