import 'capture_main.dart' show launchCaptureApp;

/// Optional Classic level capture build. Normal launches still use main.dart.
Future<void> main() => launchCaptureApp(levelCapture: true);
