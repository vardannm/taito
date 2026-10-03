enum Achievement {
  firstRun('First climb', 'Finish an Infinite run.', 1, 25),
  distance500(
    'Finding your rhythm',
    'Reach 500 m in one Infinite run.',
    500,
    50,
  ),
  distance1000(
    'Into the clouds',
    'Reach 1,000 m in one Infinite run.',
    1000,
    100,
  ),
  distance2500(
    'Above and beyond',
    'Reach 2,500 m in one Infinite run.',
    2500,
    200,
  ),
  score10000(
    'Five figures',
    'Score 10,000 points in one Infinite run.',
    10000,
    100,
  ),
  runs25('Back for more', 'Finish 25 Infinite runs.', 25, 150),
  stars12('Star collector', 'Earn 12 Classic stars.', 12, 150),
  mazeClear('A way through', 'Complete a Laser Maze route.', 1, 75),
  merge128(
    'Power of two',
    'Make a 128 tile in Merge and finish the run.',
    128,
    100,
  ),
  distance5000('Sky explorer', 'Reach 5,000 m in one Infinite run.', 5000, 350),
  score25000(
    'High roller',
    'Score 25,000 points in one Infinite run.',
    25000,
    200,
  ),
  runs100('Climbing regular', 'Finish 100 Infinite runs.', 100, 300),
  stars30('Constellation', 'Earn 30 Classic stars.', 30, 200),
  stars60('Star atlas', 'Earn 60 Classic stars.', 60, 300),
  stars120('Galaxy maker', 'Earn 120 Classic stars.', 120, 500),
  maze5('Route finder', 'Complete 5 different Laser Maze routes.', 5, 200),
  maze10('Maze navigator', 'Complete 10 different Laser Maze routes.', 10, 350),
  merge256(
    'Growing stronger',
    'Make a 256 ball in Merge and finish the run.',
    256,
    125,
  ),
  merge512(
    'Chain reaction',
    'Make a 512 ball in Merge and finish the run.',
    512,
    175,
  ),
  merge1024(
    'Four digits',
    'Make a 1,024 ball in Merge and finish the run.',
    1024,
    250,
  ),
  merge2048(
    'The namesake',
    'Make a 2,048 ball in Merge and finish the run.',
    2048,
    350,
  ),
  merge4096(
    'Beyond 2048',
    'Make a 4,096 ball in Merge and finish the run.',
    4096,
    500,
  ),
  mergeRuns25('Snake charmer', 'Finish 25 Merge runs.', 25, 150),
  mergeRuns100('Merge regular', 'Finish 100 Merge runs.', 100, 300),
  visits3(
    'Good to see you',
    'Claim daily prizes on 3 different days. Missed days keep your progress.',
    3,
    50,
  ),
  visits7(
    'A week of visits',
    'Claim daily prizes on 7 different days. Missed days keep your progress.',
    7,
    100,
  ),
  visits14(
    'Familiar face',
    'Claim daily prizes on 14 different days. Missed days keep your progress.',
    14,
    200,
  ),
  visits30(
    'Arcade regular',
    'Claim daily prizes on 30 different days. Missed days keep your progress.',
    30,
    350,
  ),
  visits60(
    'Part of the arcade',
    'Claim daily prizes on 60 different days. Missed days keep your progress.',
    60,
    600,
  );

  const Achievement(this.title, this.description, this.target, this.coins);
  final String title, description;
  final int target, coins;
}
