import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UIKit owns phone rotation; an expanded Duo may ignore its orientation mask.
Future<bool> initializeDeviceOrientation() async {
  final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  await SystemChrome.setPreferredOrientations(
    ios ? const [] : const [DeviceOrientation.portraitUp],
  );
  return ios &&
      (await const MethodChannel(
            'rollrise/device-layout',
          ).invokeMethod<bool>('isPhone') ??
          false);
}

/// Native UIKit policy locks compact phones to portrait and allows expanded
/// Duo and iPads to rotate. Preserve the native viewport and safe-area insets.
class PhoneOrientationFrame extends StatelessWidget {
  const PhoneOrientationFrame({
    super.key,
    required this.isIOSPhone,
    required this.child,
  });

  final bool isIOSPhone;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
