import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var widenObserver: NSObjectProtocol?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.view.setFrameSize(MainFlutterWindow.wide)
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 480, height: 560)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    keepWideAtLaunch()
  }

  /// The demo opens wide: side menu, preview and settings side by side.
  private static let wide = NSSize(width: 1280, height: 820)

  /// Right after launch the window is resized once to the engine's default
  /// 800 x 600; widen it again then. Later resizes are the person's own.
  private func keepWideAtLaunch() {
    widenObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResizeNotification, object: self, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      self.stopWidening()
      if self.frame.width < MainFlutterWindow.wide.width {
        self.setContentSize(MainFlutterWindow.wide)
        self.center()
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.stopWidening()
    }
  }

  private func stopWidening() {
    if let observer = widenObserver {
      NotificationCenter.default.removeObserver(observer)
      widenObserver = nil
    }
  }
}
