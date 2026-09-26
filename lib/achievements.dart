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
  );

  const Achievement(this.title, this.description, this.target, this.coins);
  final String title, description;
  final int target, coins;
}
