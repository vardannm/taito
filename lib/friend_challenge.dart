import 'dart:convert';
import 'game.dart';
import 'profile.dart';
import 'rewards.dart';

/// A shared personal Daily record, not a verified online score.
class FriendChallenge {
  const FriendChallenge({
    required this.name,
    required this.date,
    required this.control,
    required this.score,
  });
  final String name, date;
  final ControlMode control;
  final int score;
  String encode() =>
      'GILT1.${base64Url.encode(utf8.encode(jsonEncode({'name': name, 'date': date, 'control': control.name, 'score': score, 'rules': 1})))}';
  static FriendChallenge decode(String code) {
    try {
      code = code.trim();
      if (code.length > 1024 || !code.startsWith('GILT1.'))
        throw const FormatException();
      final d = jsonDecode(utf8.decode(base64Url.decode(code.substring(6))));
      if (d is! Map || d['rules'] != 1) throw const FormatException();
      final name = d['name'], date = d['date'], score = d['score'];
      if (name is! String ||
          !RegExp(r'^[a-zA-Z0-9 _-]{1,24}$').hasMatch(name) ||
          name.trim().isEmpty ||
          date is! String ||
          !RegExp(r'^20\d{2}-\d{2}-\d{2}$').hasMatch(date) ||
          score is! int ||
          score < 0 ||
          score > 10000000)
        throw const FormatException();
      final day = DateTime.parse('${date}T00:00:00Z');
      if (DailyChallenge.key(day) != date ||
          day.isAfter(DailyChallenge.day(DateTime.now())))
        throw const FormatException();
      final control = ControlMode.values
          .where((m) => m.name == d['control'])
          .first;
      return FriendChallenge(
        name: name.trim(),
        date: date,
        control: control,
        score: score,
      );
    } catch (_) {
      throw const FormatException(
        'Invalid challenge code or unsupported rules.',
      );
    }
  }

  int yourScore(PlayerProfile p) => p.dailyRecord(date, control).bestScore;
}
