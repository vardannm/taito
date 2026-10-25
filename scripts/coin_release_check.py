"""Detect previously used testing-coin shortcuts in production Dart sources."""
import re


def testing_coin_blockers(profile_source, main_source):
    source = profile_source + "\n" + main_source
    blockers = []
    if re.search(r"\bgrant(?:TemporaryNormal|BallTest)Coins\s*\(", source):
        blockers.append("Remove automatic testing-coin grants before store release.")
    if re.search(r"\bwallet\s*(?:=|\+=)\s*(?:99_?999|100_?000|10_?000)\b", source):
        blockers.append("Remove the hard-coded testing wallet/coin credit before store release.")
    if re.search(r"\b(?:bool\.fromEnvironment|bool\.hasEnvironment)\s*\(\s*['\"]GILT_UNLIMITED_COINS['\"]", source):
        blockers.append("Remove the unlimited-coin build flag from the app's normal profile.")
    return blockers
