import 'rewards.dart';

/// A continuous visit count, with one claim per UTC calendar day.
/// Rewards repeat every five claims; missed days keep the accumulated count.
class DailyPrizes {
  int claimed = 0;
  DateTime? lastClaim;
  static const coins = [10, 15, 20, 25];
  static const rewardInterval = 5;

  int get nextDay => claimed + 1;
  static bool isGearDay(int day) => day % rewardInterval == 0;

  /// Gear days grant these coins when the eligible collection is complete.
  static int coinReward(int day) =>
      isGearDay(day) ? 100 : coins[(day - 1) % rewardInterval];
  bool canClaim(DateTime now) =>
      lastClaim == null || DailyChallenge.day(now).isAfter(lastClaim!);
  int displayedDay(DateTime now) => canClaim(now) ? nextDay : claimed;

  int firstDisplayedDay(DateTime now) =>
      (displayedDay(now) - 1) ~/ rewardInterval * rewardInterval + 1;

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
