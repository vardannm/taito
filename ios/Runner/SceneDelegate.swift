import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    // Reapply after returning from Control Center, the app switcher, or an ad.
    (window?.rootViewController as? PortraitFlutterViewController)?
      .enforcePortraitOrientation()
  }
}
