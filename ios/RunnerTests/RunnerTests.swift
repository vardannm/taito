import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  @MainActor
  func testLaunchStoryboardUsesResponsiveController() throws {
    let bundle = Bundle(for: AppDelegate.self)
    let storyboard = UIStoryboard(name: "Main", bundle: bundle)
    let controller = try XCTUnwrap(
      storyboard.instantiateInitialViewController() as? ResponsiveFlutterViewController
    )
    XCTAssertNotNil(controller)
    // Bundle.object applies the host device's ~ipad override automatically.
    // Inspect the file itself when checking both declared device families.
    let info = try XCTUnwrap(
      PropertyListSerialization.propertyList(
        from: Data(contentsOf: bundle.bundleURL.appendingPathComponent("Info.plist")),
        options: [], format: nil
      ) as? [String: Any]
    )
    XCTAssertEqual(
      info["UISupportedInterfaceOrientations"] as? [String],
      ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
       "UIInterfaceOrientationLandscapeRight"]
    )
    XCTAssertEqual(
      info["UISupportedInterfaceOrientations~ipad"] as? [String],
      ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
       "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]
    )
  }

  @MainActor
  func testCompactPhonesStayPortraitInEitherPhysicalOrientation() {
    for size in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390),
                 CGSize(width: 540, height: 720), CGSize(width: 720, height: 540)] {
      XCTAssertEqual(
        ResponsiveFlutterViewController.orientationMask(for: size, idiom: .phone), .portrait
      )
    }
  }

  @MainActor
  func testUnfoldedDuoSupportsPortraitAndLandscapeAndFoldingRestoresPortrait() {
    for size in [CGSize(width: 1114, height: 720), CGSize(width: 720, height: 1114),
                 CGSize(width: 951, height: 669), CGSize(width: 669, height: 951)] {
      XCTAssertEqual(
        ResponsiveFlutterViewController.orientationMask(for: size, idiom: .phone),
        .allButUpsideDown
      )
    }
    XCTAssertEqual(
      ResponsiveFlutterViewController.orientationMask(
        for: CGSize(width: 540, height: 720), idiom: .phone
      ), .portrait
    )
  }

  @MainActor
  func testIPadKeepsAllOrientationsIncludingSmallWindows() {
    for size in [CGSize(width: 820, height: 1180), CGSize(width: 1180, height: 820),
                 CGSize(width: 540, height: 720)] {
      XCTAssertEqual(
        ResponsiveFlutterViewController.orientationMask(for: size, idiom: .pad), .all
      )
    }
  }

  @MainActor
  func testSceneOrientationAndDisplayChangeCallback() throws {
    if #available(iOS 27.0, *) {
      let scene = try XCTUnwrap(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
      )
      let delegate = SceneDelegate()
      delegate.window = scene.windows.first
      XCTAssertEqual(
        delegate.supportedInterfaceOrientations(for: scene),
        ResponsiveFlutterViewController.orientationMask(
          for: scene.effectiveGeometry.coordinateSpace.bounds.size,
          idiom: scene.traitCollection.userInterfaceIdiom
        )
      )
      // This optional callback must not call an unimplemented superclass method.
      delegate.windowScene(scene, didUpdateEffectiveGeometry: scene.effectiveGeometry)
    }
  }

}
