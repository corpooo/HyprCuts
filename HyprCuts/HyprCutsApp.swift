import SwiftUI

@main
struct HyprCutsApp: App {
    // Use AppDelegateAdaptor to link to our custom AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // No WindowGroup scene needed for a menu bar only app
    var body: some Scene {
        // We use Settings scene if we want a Preferences window later,
        // but it's not strictly required for basic operation.
        // Remove it if you don't plan on having a standard Preferences window.
        Settings {
            EmptyView()  // Placeholder for potential future settings UI
        }
    }
}

// Create the AppDelegate class
class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong reference to the status bar item
    private var statusItem: NSStatusItem?
    // Potential popover reference if using SwiftUI for menu UI later
    // private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("HyprCuts App finished launching!")
        setupMenuBar()

        // TODO: Initialize Keyboard Monitor
        // TODO: Initialize Config Manager (Load initial config)
        // TODO: Check Accessibility Permissions
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("HyprCuts App will terminate.")
        // TODO: Perform any necessary cleanup
    }

    private func setupMenuBar() {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Configure the status bar button
        if let button = statusItem?.button {
            // Use an SF Symbol for the icon (requires macOS 11+)
            button.image = NSImage(
                systemSymbolName: "keyboard.fill", accessibilityDescription: "HyprCuts")
            // Define the action for clicking the button (usually shows the menu)
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])  // Respond to left/right clicks
            button.target = self
        }

        // Build the menu
        constructMenu()
    }

    private func constructMenu() {
        let menu = NSMenu()

        // Example Items (Align with AC5.2)
        // TODO: Add state tracking for Enable/Disable
        menu.addItem(
            NSMenuItem(title: "Enable", action: #selector(toggleEnable(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())  // Separator line
        menu.addItem(
            NSMenuItem(title: "Restart", action: #selector(restartApp(_:)), keyEquivalent: ""))
        menu.addItem(
            NSMenuItem(
                title: "Reload Config", action: #selector(reloadConfig(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        // TODO: Display actual master key
        let masterKeyItem = NSMenuItem(
            title: "Master Key: (Not Set)", action: nil, keyEquivalent: "")
        masterKeyItem.isEnabled = false  // Display only
        menu.addItem(masterKeyItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit HyprCuts", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))

        // Assign the menu to the status item
        statusItem?.menu = menu
    }

    // Action triggered by clicking the status bar item button
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        // The system automatically shows the menu assigned to statusItem.menu
        // when the button is configured correctly (as it is in setupMenuBar).
        // So, the popUpMenu call is no longer needed here for standard behavior.

        // --- Optional: Keep this function for advanced behavior ---
        // You might still need this function if you want to:
        // 1. Distinguish between left and right clicks:
        //    if let event = NSApp.currentEvent, event.type == .rightMouseUp {
        //        print("Right click detected!")
        //        // Maybe show a different menu or perform a different action?
        //        // statusItem?.popUpMenu(someOtherMenu)
        //    } else {
        //        // For left-click, the default menu assigned to statusItem.menu
        //        // will usually show automatically *without* needing code here.
        //        print("Left click detected (default menu should show automatically)")
        //    }
        //
        // 2. Show a Popover instead of a menu:
        //    // self.togglePopover(sender) // Example function call
        //
        // If you only need the default menu on left-click, you could even
        // potentially remove this action method entirely, *IF* you also remove
        // the .target and .action assignment in setupMenuBar. However, it's often
        // useful to keep the action method for future flexibility.

        print("Status bar button clicked. Default menu should appear if set.")  // Optional print for debugging
    }
    // --- Placeholder Menu Actions ---

    @objc func toggleEnable(_ sender: Any?) {
        print("Toggle Enable/Disable action triggered")
        // TODO: Implement enable/disable logic
        // TODO: Update menu item title/state (checkmark)
    }

    @objc func restartApp(_ sender: Any?) {
        print("Restart action triggered")
        // TODO: Implement restart logic (might involve launching a helper script/task)
        // A simple way is to terminate and rely on the user/launchd to restart,
        // or use Process to relaunch the app bundle.
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        NSApp.terminate(nil)

    }

    @objc func reloadConfig(_ sender: Any?) {
        print("Reload Config action triggered")
        // TODO: Tell the ConfigManager to reload
    }
}
