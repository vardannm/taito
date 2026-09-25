part of '../classic_levels.dart';

// Classic level 1. Coordinates use the 360 x 560 board.
const classicLevel01 = ClassicLevelDefinition(
  name: "First steps",
  holes: [
    Hole(180, 448, target: 1),
    Hole(228, 406, target: 2),
    Hole(132, 364, target: 3),
    Hole(204, 322, target: 4),
    Hole(252, 280, target: 5),
    Hole(156, 238, target: 6),
    Hole(108, 196, target: 7),
    Hole(180, 154, target: 8),
    Hole(228, 112, target: 9),
    Hole(156, 62, target: 10),
    Hole(76, 398),
    Hole(292, 338),
    Hole(72, 266),
  ],
  // Spider patrol centers and movement settings.
  spiders: [],
  // Spawn positions for each numbered target; waves repeat in order.
  hazards: [],
);
