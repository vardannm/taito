import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  @MainActor
  func testLaunchStoryboardUsesPortraitController() throws {
    let bundle = Bundle(for: AppDelegate.self)
    let storyboard = UIStoryboard(name: "Main", bundle: bundle)
    let controller = try XCTUnwrap(
      storyboard.instantiateInitialViewController() as? PortraitFlutterViewController
    )
    XCTAssertEqual(controller.supportedInterfaceOrientations, .portrait)
    XCTAssertEqual(controller.preferredInterfaceOrientationForPresentation, .portrait)
    XCTAssertEqual(
      bundle.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String],
      ["UIInterfaceOrientationPortrait"]
    )
    XCTAssertEqual(
      bundle.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations~ipad") as? [String],
      ["UIInterfaceOrientationPortrait"]
    )
  }

}
