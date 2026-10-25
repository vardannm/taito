part of '../classic_levels.dart';

// Classic level 5. Coordinates use the 360 x 560 board.
const classicLevel05 = ClassicLevelDefinition(
  name: "Open crossing",
  holes: [
    Hole(190, 450, target: 1),
    Hole(286, 366, target: 2),
    Hole(126, 408, target: 3),
    Hole(246, 240, target: 4),
    Hole(108, 324, target: 5),
    Hole(226, 156, target: 6),
    Hole(82, 282, target: 7),
    Hole(250, 72, target: 8),
    Hole(140, 198, target: 9),
    Hole(278, 114, target: 10),
    Hole(52, 432),
    Hole(184, 388),
    Hole(228, 388),
    Hole(52, 344),
    Hole(184, 300),
    Hole(184, 256),
    Hole(316, 256),
    Hole(24, 200),
    Hole(70, 210),
    Hole(336, 330),
    Hole(240, 100),
    Hole(130, 250),
  ],
  spiders: [
  ],
  finaleTitle: "",
  finaleRule: "",
  hazards: [
  ],
  firstHazardAfter: 3,
  hazardInterval: 9,
);
