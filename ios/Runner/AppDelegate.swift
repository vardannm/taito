import Flutter
import UIKit

// Keep this in an existing Runner source so every Xcode build includes it.
@objc(PortraitFlutterViewController)
class PortraitFlutterViewController: FlutterViewController {
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }

  override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
    return .portrait
  }

  // Xcode 26 (Swift 6.2) introduced this UIKit API. Older SDKs keep using
  // the portrait mask and UIRequiresFullScreen compatibility behavior.
  #if compiler(>=6.2)
  @available(iOS 26.0, *)
  override var prefersInterfaceOrientationLocked: Bool {
    // Never lock an existing landscape scene before it reaches portrait.
    return viewIfLoaded?.window?.windowScene?.interfaceOrientation == .portrait
  }
  #endif

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    enforcePortraitOrientation()
  }

  override func viewWillTransition(
    to size: CGSize,
    with coordinator: UIViewControllerTransitionCoordinator
  ) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: nil) { [weak self] _ in
      self?.enforcePortraitOrientation()
    }
  }

  func enforcePortraitOrientation() {
    guard let scene = viewIfLoaded?.window?.windowScene else { return }
    if #available(iOS 16.0, *) {
      setNeedsUpdateOfSupportedInterfaceOrientations()
      if scene.interfaceOrientation != .portrait {
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
          NSLog("Rollrise portrait orientation request failed: %@", error.localizedDescription)
        }
      }
    }
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      setNeedsUpdateOfPrefersInterfaceOrientationLocked()
    }
    #endif
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
