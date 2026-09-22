import AppKit
import Darwin

setvbuf(stdout, nil, _IONBF, 0)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = AppController()
controller.start()

app.run()
