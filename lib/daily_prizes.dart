import 'rewards.dart';

/// Five visits, with one claim per UTC calendar day. Missed days keep progress.
class DailyPrizes {
  int claimed = 0;
  DateTime? lastClaim;
  static const coins = [10, 15, 20, 25];

  int get nextDay => claimed % 5 + 1;
  bool canClaim(DateTime now) =>
      lastClaim == null || DailyChallenge.day(now).isAfter(lastClaim!);
  int displayedDay(DateTime now) =>
      canClaim(now) ? nextDay : (claimed - 1) % 5 + 1;

  Map<String, Object?> toJson() => {
    'claimed': claimed,
    'lastClaim': lastClaim == null ? null : DailyChallenge.key(lastClaim!),
  };

  static DailyPrizes fromJson(dynamic data) {
    final result = DailyPrizes();
    if (data is! Map<String, dynamic>) return result;
    final count = data['claimed'];
    final raw = data['lastClaim'];
    final date = raw is String ? DateTime.tryParse('${raw}T00:00:00Z') : null;
    if (count is int &&
        count > 0 &&
        count <= 1 << 30 &&
        date != null &&
        DailyChallenge.key(date) == raw) {
      result.claimed = count;
      result.lastClaim = date;
    }
    return result;
  }
}
