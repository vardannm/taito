part of '../classic_levels.dart';

// Classic level 1. Coordinates use the 360 x 560 board.
const classicLevel01 = ClassicLevelDefinition(
  name: "First steps",
  holes: [
    Hole(219.91315554897346, 454.66149743686066, target: 1),
    Hole(121.04492742978314, 363.8678152780807, target: 2),
    Hole(288.00952630750436, 410.50793320151524, target: 3),
    Hole(191.41515810389708, 276.1892976474679, target: 4),
    Hole(299.77535181194025, 319.3156568082424, target: 5),
    Hole(132.25320202973285, 194.04313582660626, target: 6),
    Hole(236.8352504228107, 223.40581802026244, target: 7),
    Hole(51.04656953416895, 92.42481093999136, target: 8),
    Hole(234.24681199080686, 142.67985064882552, target: 9),
    Hole(129.364224759094, 44.709628475585426, target: 10),
    Hole(71.28357350065882, 318.0368892597387),
    Hole(103.40860593121899, 466.5432768441626),
    Hole(281.11551308879103, 120.13450200666291),
    Hole(70.09446883061818, 391.6769485757184),
    Hole(48.74098368831518, 179.36299842375172),
  ],
  // Spider patrol centers and movement settings.
  spiders: [],
  // Spawn positions for each numbered target; waves repeat in order.
  hazards: [],
);
