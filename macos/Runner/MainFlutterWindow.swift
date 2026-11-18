import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Projector-friendly default size, centred.
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.minSize = NSSize(width: 1100, height: 720)
    self.center()
    self.title = "Day Planner"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
