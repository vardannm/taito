part of '../classic_levels.dart';

// Classic level 6. Coordinates use the 360 x 560 board.
const classicLevel06 = ClassicLevelDefinition(
  name: "Left bank",
  holes: [
    Hole(148, 450, target: 1),
    Hole(244, 366, target: 2),
    Hole(100, 408, target: 3),
    Hole(218, 198, target: 4),
    Hole(82, 282, target: 5),
    Hole(238, 114, target: 6),
    Hole(126, 324, target: 7),
    Hole(270, 240, target: 8),
    Hole(94, 72, target: 9),
    Hole(206, 156, target: 10),
    Hole(235, 432),
    Hole(275, 432),
    Hole(75, 344),
    Hole(267, 300),
    Hole(67, 212),
    Hole(107, 212),
    Hole(275, 168),
    Hole(24, 280),
    Hole(330, 240),
    Hole(330, 360),
    Hole(170, 370),
    Hole(160, 190),
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
