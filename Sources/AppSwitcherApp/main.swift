import AppKit
import Darwin

setvbuf(stdout, nil, _IONBF, 0)
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    #if !DEBUG
    if CommandLine.arguments.contains("--verify-commerce-api") || CommandLine.arguments.contains("--render-commerce-preview") {
        fputs("This isolated development command is unavailable in release builds.\n", stderr)
        exit(2)
    }
    #endif
    #if DEBUG
    if let index = CommandLine.arguments.firstIndex(of: "--verify-commerce-api"), CommandLine.arguments.count > index + 1 {
        let fixture = URL(fileURLWithPath: CommandLine.arguments[index + 1])
        Task { @MainActor in exit(Int32(await CommerceAPIProbe.run(fixtureURL: fixture))) }
        app.run()
        exit(1)
    }
    if let index = CommandLine.arguments.firstIndex(of: "--render-commerce-preview"), CommandLine.arguments.count > index + 1 {
        do {
            for url in try CommerceAccountPreview.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) { print(url.path) }
            exit(0)
        } catch {
            fputs("Account preview failed.\n", stderr)
            exit(1)
        }
    }
    #endif
    if let index = CommandLine.arguments.firstIndex(of: "--verify-commerce-fixture"), CommandLine.arguments.count > index + 1 {
        exit(Int32(CommerceProbe.verifyFixture(at: URL(fileURLWithPath: CommandLine.arguments[index + 1]))))
    } else if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > index + 1 {
        do {
            for url in try OverlayPreview.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) {
                print(url.path)
            }
            exit(0)
        } catch {
            fputs("Preview failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    } else if let index = CommandLine.arguments.firstIndex(of: "--render-settings-preview"), CommandLine.arguments.count > index + 1 {
        do {
            for url in try ShortcutSettingsPreview.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) {
                print(url.path)
            }
            exit(0)
        } catch {
            fputs("Settings preview failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    } else if CommandLine.arguments.contains("--verify-commerce") {
        exit(Int32(CommerceProbe.run()))
    } else if CommandLine.arguments.contains("--verify-shortcuts") {
        exit(Int32(ShortcutRegistrationProbe.run()))
    } else if CommandLine.arguments.contains("--verify-app-activation") {
        Task { @MainActor in exit(Int32(await AppActivationProbe.run())) }
        app.run()
    } else if CommandLine.arguments.contains("--verify-window-switching") {
        Task { @MainActor in exit(Int32(await WindowSwitchingProbe.run())) }
        app.run()
    } else {
        let controller = AppController()
        controller.start()
        if CommandLine.arguments.contains("--show-account") {
            DispatchQueue.main.async { controller.showAccount() }
        } else if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.async { controller.showShortcutSettings() }
        } else if CommandLine.arguments.contains("--show-switcher") {
            DispatchQueue.main.async { controller.showSwitcher() }
        }
        withExtendedLifetime(controller) { app.run() }
    }

}
