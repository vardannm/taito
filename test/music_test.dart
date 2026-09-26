import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a quiet screen never reaches for the audio platform', () async {
    final feedback = GameFeedback();
    // Every screen outside Infinite and 2048 asks for no track, repeatedly.
    // That must stay a no-op: no player is built, so nothing can fail and
    // nothing plays over a mode that wants silence.
    for (var i = 0; i < 5; i++) {
      await feedback.updateMusic(track: null, playing: i.isEven);
    }
    feedback.dispose();
  });
}
