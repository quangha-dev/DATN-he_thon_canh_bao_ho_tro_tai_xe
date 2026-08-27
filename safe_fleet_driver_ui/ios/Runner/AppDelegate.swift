import Flutter
import GoogleMaps
import GoogleNavigation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let mapsApiKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_IOS_API_KEY"]
      ?? findDartDefine("GOOGLE_MAPS_IOS_API_KEY")
      ?? ""
    if !mapsApiKey.isEmpty {
      GMSServices.provideAPIKey(mapsApiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func findDartDefine(_ key: String) -> String? {
    guard let raw = Bundle.main.infoDictionary?["DART_DEFINES"] as? String else { return nil }
    for encoded in raw.components(separatedBy: ",") {
      guard let data = Data(base64Encoded: encoded),
            let value = String(data: data, encoding: .utf8) else { continue }
      let pair = value.split(separator: "=", maxSplits: 1).map(String.init)
      if pair.count == 2 && pair[0] == key { return pair[1] }
    }
    return nil
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
