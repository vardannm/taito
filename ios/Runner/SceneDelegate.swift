import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  @available(iOS 27.0, *)
  override func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
    ResponsiveFlutterViewController.orientationMask(
      for: windowScene.effectiveGeometry.coordinateSpace.bounds.size,
      idiom: windowScene.traitCollection.userInterfaceIdiom
    )
  }

  @available(iOS 26.0, *)
  override func windowScene(
    _ windowScene: UIWindowScene, didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry
  ) {
    // FlutterSceneDelegate doesn't implement this optional UIKit callback.
    (window?.rootViewController as? ResponsiveFlutterViewController)?
      .updateOrientationForCurrentDisplay()
  }
}
