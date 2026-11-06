import Flutter
import UIKit

// Match Flutter's 600-point compact-control threshold regardless of rotation.
// Expanded phones and iPads rotate; compact phones stay portrait.
@objc(ResponsiveFlutterViewController)
class ResponsiveFlutterViewController: FlutterViewController {
  private var lastOrientationMask: UIInterfaceOrientationMask?

  static func orientationMask(
    for size: CGSize, idiom: UIUserInterfaceIdiom
  ) -> UIInterfaceOrientationMask {
    if idiom == .pad { return .all }
    return min(size.width, size.height) < 600 ? .portrait : .allButUpsideDown
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    let size = viewIfLoaded?.window?.bounds.size
      ?? viewIfLoaded?.bounds.size
      ?? .zero
    return Self.orientationMask(for: size, idiom: traitCollection.userInterfaceIdiom)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateOrientationForCurrentDisplay()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    updateOrientationForCurrentDisplay()
  }

  func updateOrientationForCurrentDisplay() {
    guard let scene = view.window?.windowScene else { return }
    let mask = supportedInterfaceOrientations
    guard mask != lastOrientationMask else { return }
    lastOrientationMask = mask
    // Follow the inner display naturally; restore portrait on the outer one.
    if #available(iOS 16.0, *) {
      setNeedsUpdateOfSupportedInterfaceOrientations()
      if mask == .portrait {
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
          NSLog("Rollrise orientation update failed: %@", error.localizedDescription)
        }
      }
    } else {
      UIViewController.attemptRotationToDeviceOrientation()
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var captureExportChannel: FlutterMethodChannel?
  private var deviceLayoutChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RollriseDeviceLayout") {
      let channel = FlutterMethodChannel(name: "rollrise/device-layout", binaryMessenger: registrar.messenger())
      deviceLayoutChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "isPhone" {
          result(UIDevice.current.userInterfaceIdiom == .phone)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    // Only the separate capture entrypoint calls this local file exporter.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RollriseCaptureExport") else { return }
    let channel = FlutterMethodChannel(name: "rollrise/capture-export", binaryMessenger: registrar.messenger())
    captureExportChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "share", let json = call.arguments as? String,
            json.utf8.count <= 20 * 1024 * 1024 else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("rollrise-capture.json")
        try Data(json.utf8).write(to: url, options: .atomic)
        guard var presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
          .flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
          result(FlutterError(code: "no_window", message: "No window available to export the take.", details: nil))
          return
        }
        while let next = presenter.presentedViewController { presenter = next }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = presenter.view
        share.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        share.completionWithItemsHandler = { _, completed, _, error in
          if let error = error {
            result(FlutterError(code: "export_failed", message: error.localizedDescription, details: nil))
          } else { result(completed) }
        }
        presenter.present(share, animated: true)
      } catch {
        result(FlutterError(code: "export_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
