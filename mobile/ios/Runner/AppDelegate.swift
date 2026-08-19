import Flutter
import UIKit
import AVFoundation
import AVKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioRouteChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      setupAudioRouteChannel(binaryMessenger: controller.binaryMessenger)
    }

    return result
  }

  private func setupAudioRouteChannel(binaryMessenger: FlutterBinaryMessenger) {
    if audioRouteChannel != nil { return }
    audioRouteChannel = FlutterMethodChannel(name: "com.muxiz.app/audio_route", binaryMessenger: binaryMessenger)

    audioRouteChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }

      switch call.method {
      case "getAvailableRoutes":
        result(self.fetchAudioRoutes())

      case "selectRoute":
        if let args = call.arguments as? [String: Any] {
          let success = self.routeAudio(args: args)
          result(success)
        } else {
          result(false)
        }

      case "showSystemRoutePicker":
        self.presentSystemRoutePicker()
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // Listen for real-time audio route changes (AirPods connected/disconnected, speaker override, AirPlay)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(audioRouteChanged(notification:)),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
  }

  @objc private func audioRouteChanged(notification: Notification) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let channel = self.audioRouteChannel else { return }
      let routesData = self.fetchAudioRoutes()
      channel.invokeMethod("onRouteChange", arguments: routesData)
    }
  }

  private func fetchAudioRoutes() -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    let currentRoute = session.currentRoute

    var activeRouteId = "speaker"
    var activeRouteType = "speaker"
    var activeRouteName = "iPhone Speaker"

    var routesMap: [String: [String: Any]] = [:]

    // 1. Built-in Speaker (Always an available hardware target)
    let speakerMap: [String: Any] = [
      "id": "speaker",
      "name": "iPhone Speaker",
      "type": "speaker",
      "isSelected": false,
      "isAvailable": true
    ]
    routesMap["speaker"] = speakerMap

    // 2. Active Output Ports from AVAudioSession
    for output in currentRoute.outputs {
      let routeType = mapPortType(output.portType, name: output.portName)
      activeRouteId = output.uid
      activeRouteType = routeType
      activeRouteName = output.portName

      let item: [String: Any] = [
        "id": output.uid,
        "name": output.portName,
        "type": routeType,
        "isSelected": true,
        "isAvailable": true,
        "batteryLevel": routeType == "airpods" ? 100 : nil as Any? as Any
      ]
      routesMap[output.uid] = item
    }

    // 3. Available Inputs / Bluetooth devices that can be targeted
    if let availableInputs = session.availableInputs {
      for input in availableInputs {
        let routeType = mapPortType(input.portType, name: input.portName)
        let isCurrent = (input.uid == activeRouteId)

        if routesMap[input.uid] == nil {
          routesMap[input.uid] = [
            "id": input.uid,
            "name": input.portName,
            "type": routeType,
            "isSelected": isCurrent,
            "isAvailable": true,
            "batteryLevel": routeType == "airpods" ? 100 : nil as Any? as Any
          ]
        }
      }
    }

    // Determine current route selection
    let isSpeakerActive = (activeRouteType == "speaker" || currentRoute.outputs.contains { $0.portType == .builtInSpeaker })
    if var sp = routesMap["speaker"] {
      sp["isSelected"] = isSpeakerActive
      routesMap["speaker"] = sp
    }

    let currentRouteMap: [String: Any] = [
      "id": activeRouteId,
      "name": activeRouteName,
      "type": activeRouteType,
      "isSelected": true,
      "isAvailable": true
    ]

    return [
      "currentRoute": currentRouteMap,
      "availableRoutes": Array(routesMap.values)
    ]
  }

  private func mapPortType(_ port: AVAudioSession.Port, name: String) -> String {
    let lowerName = name.lowercased()
    if lowerName.contains("airpod") {
      return "airpods"
    }

    switch port {
    case .builtInSpeaker, .builtInReceiver:
      return "speaker"
    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
      return "bluetooth"
    case .headphones, .headsetMic:
      return "headphones"
    case .airPlay:
      return "airplay"
    case .carAudio:
      return "car"
    case .usbAudio:
      return "usb"
    default:
      return "bluetooth"
    }
  }

  private func routeAudio(args: [String: Any]) -> Bool {
    let session = AVAudioSession.sharedInstance()
    let type = (args["type"] as? String)?.lowercased() ?? ""

    do {
      if type == "speaker" {
        try session.overrideOutputAudioPort(.speaker)
      } else {
        try session.overrideOutputAudioPort(.none)
      }
      return true
    } catch {
      print("AVAudioSession route error: \(error)")
      return false
    }
  }

  private func presentSystemRoutePicker() {
    DispatchQueue.main.async {
      if #available(iOS 11.0, *) {
        let routePickerView = AVRoutePickerView()
        routePickerView.isHidden = true
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
          window.addSubview(routePickerView)
          for subview in routePickerView.subviews {
            if let button = subview as? UIButton {
              button.sendActions(for: .touchUpInside)
              break
            }
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            routePickerView.removeFromSuperview()
          }
        }
      }
    }
  }
}
