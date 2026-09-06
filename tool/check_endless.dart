import '../lib/game.dart';
void main() {
  final game = BalanceGame()..start(gameMode: GameMode.infinite);
  final positions = <String, double>{};
  for (int i = 0; i < 2000; i++) {
    final height = i * 5.0;
    final y = 519 - height;
    final x = [180.0, 70.0, 290.0, 120.0, 240.0].firstWhere((x) => game.board.every((h) => (x-h.x)*(x-h.x)+(y-h.y)*(y-h.y)>324));
    game.left = game.right = y+7; game.ballX=x; game.velocity=game.leftSpeed=game.rightSpeed=0;
    game.step(1/120);
    for (final h in game.board) { positions['${h.x}:${h.y}']=h.x; }
    if (game.finished || game.board.length>40) throw StateError('Climb/generation failed at $height');
  }
  final gaps=<int>[];
  for (int x=28;x<=332;x+=2) {
    if (!positions.values.any((p)=>(p-x).abs()<8.5)) gaps.add(x);
  }
  if (gaps.isNotEmpty) throw StateError('Unchallenged vertical lanes: $gaps');
  print('Climbed 999.5m in simulation; bounded hazards; all fixed vertical lanes encounter hazards.');
}
