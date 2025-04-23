import ApplicationServices  // Import for Accessibility APIs
import CoreGraphics
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

    private var popover: NSPopover?

    // MARK: - Dependencies
    private var keyboardMonitor: KeyboardMonitor?
    private var permissionPollTimer: Timer?

    // MARK: - State
    private var hasAccessibilityPermissions: Bool = false
    private var isWaitingForPermissions: Bool = false
}

// Create the AppDelegate class
class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong reference to the status bar item
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?  // Keep track of the menu

    // MARK: - Dependencies
    private var keyboardMonitor: KeyboardMonitor?
    private var permissionPollTimer: Timer?
    private var actionExecutor: ActionExecutor?  // Added ActionExecutor instance

    // MARK: - State
    private var hasAccessibilityPermissions: Bool = false
    private var isWaitingForPermissions: Bool = false

    // MARK: - NSApplicationDelegate Methods
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("HyprCuts App finished launching!")

        // Initialize Config Manager (loads initial config)
        _ = ConfigManager.shared  // Access singleton to trigger init and initial load

        checkAccessibilityPermissions()

        // Initialize Action Executor
        actionExecutor = ActionExecutor()

        setupMenuBar()
        // setupEventTap() // <-- Removed: Now handled by KeyboardMonitor

        // Initialize Keyboard Monitor only if permissions are initially granted
        if hasAccessibilityPermissions {
            initializeAndStartKeyboardMonitor()
        } else {
            print("Keyboard Monitor not started. Waiting for Accessibility permissions.")
            // TODO: Update UI to clearly indicate permissions are needed (Task 28)
        }

        // TODO: Add logic to update menu bar state based on permissions (Task 28)
        // TODO: Add logic to prompt user if permissions are missing (Task 4)
    }

    // Called when the app becomes active (e.g., returning from System Settings)
    func applicationDidBecomeActive(_ notification: Notification) {
        print("Application became active.")
        // Note: Permission checking after prompt is now handled by the timer polling mechanism.
        // This method remains for other potential activation tasks.
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("HyprCuts App will terminate.")
        // Stop the keyboard monitor
        keyboardMonitor?.stop()
        // Stop the timer if it's running
        permissionPollTimer?.invalidate()
        // TODO: Perform any necessary cleanup
    }

    // MARK: - Initialization Helpers
    private func initializeAndStartKeyboardMonitor() {
        guard keyboardMonitor == nil else {
            print("Keyboard Monitor already initialized.")
            return
        }
        print("Initializing and starting Keyboard Monitor...")
        // Ensure we have an actionExecutor instance
        guard let executor = self.actionExecutor else {
            print("ERROR: ActionExecutor not initialized before KeyboardMonitor.")
            // TODO: Handle this error state more robustly
            return
        }
        keyboardMonitor = KeyboardMonitor(actionExecutor: executor)  // Pass ActionExecutor
        keyboardMonitor?.start()
    }

    // MARK: - Accessibility Permissions
    @objc private func pollForPermissions() {
        print("Polling for accessibility permissions...")
        let checkOptions: [String: Bool] = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false
        ]
        let currentlyTrusted = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)

        if currentlyTrusted {
            print("Permissions granted during polling.")
            hasAccessibilityPermissions = true
            isWaitingForPermissions = false

            // Stop the timer
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil

            // Start the keyboard monitor if it wasn't already
            if keyboardMonitor == nil {
                initializeAndStartKeyboardMonitor()
            }
            // TODO: Update UI to normal state (Task 28)

        } else {
            print("Permissions still not granted.")
        }
    }

    private func checkAccessibilityPermissions() {
        // Check if the app is already trusted *without* prompting initially
        let checkOptions: [String: Bool] = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false
        ]
        hasAccessibilityPermissions = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)

        if hasAccessibilityPermissions {
            print("Accessibility permissions granted.")
            permissionPollTimer?.invalidate()  // Stop polling if manually re-checked and OK
            permissionPollTimer = nil
            isWaitingForPermissions = false
            // TODO: Update UI to normal state if it was previously showing a warning (Task 28)
        } else {
            print("Accessibility permissions not granted. Prompting user.")
            isWaitingForPermissions = true
            // Prompt the user to grant permissions. This opens the system dialog.
            let promptOptions: [String: Bool] = [
                kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
            ]
            _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
            // Don't re-check here. Will check again in applicationDidBecomeActive.
            // Instead, start a timer to poll for permission changes.
            if permissionPollTimer == nil {
                print("Starting timer to poll for permissions...")
                permissionPollTimer = Timer.scheduledTimer(
                    timeInterval: 2.0,  // Poll every 2 seconds
                    target: self,
                    selector: #selector(pollForPermissions),
                    userInfo: nil,
                    repeats: true
                )
                // Add to runloop to ensure it fires even if menu is open
                RunLoop.current.add(permissionPollTimer!, forMode: .common)
            }

            // TODO: Implement Task 28: Update menu bar icon state (e.g., show a warning icon).
            // Note: The app might still function partially without permissions,
            // but core features requiring event taps will fail.
        }
    }

    // MARK: - Menu Bar Setup
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
        let masterKey = ConfigManager.shared.getMasterKey() ?? "(Not Set)"
        let masterKeyItem = NSMenuItem(
            title: "Master Key: \(masterKey)", action: nil, keyEquivalent: "")
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
        ConfigManager.shared.reloadConfig()
        // Rebuild the menu to reflect potential changes (like master key)
        constructMenu()
        // Notify keyboard monitor about the potential change
        keyboardMonitor?.updateConfigValues()
        print("Config reloaded and menu updated.")
    }

    // MARK: - Event Tap Setup & Handling
    // Removed: setupEventTap(), masterKeyHeldTimerFired(_:), postSynthesizedKeyEvent(...)
    // These are now in KeyboardMonitor.swift
}
