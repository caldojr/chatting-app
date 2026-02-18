import Flutter
import UIKit

@main
<<<<<<< HEAD
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
=======
@objc class AppDelegate: FlutterAppDelegate {
>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
<<<<<<< HEAD
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
=======
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
}
