import ApplicationServices  // Import for Accessibility APIs
import Combine  // Needed for Combine subscriptions
import CoreGraphics
import SwiftUI
import os  // Add import for os.Logger

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

    // Removed unused properties from here, they belong in AppDelegate if needed
    // private var popover: NSPopover?
    // private var keyboardMonitor: KeyboardMonitor?
    // private var permissionPollTimer: Timer?
    // private var hasAccessibilityPermissions: Bool = false
    // private var isWaitingForPermissions: Bool = false
}

// MARK: - Application Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    // Logger instance
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

    // Strong reference to the status bar item
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?  // Keep track of the menu

    // MARK: - Dependencies
    private var keyboardMonitor: KeyboardMonitor?
    private var permissionPollTimer: Timer?
    private var actionExecutor: ActionExecutor?  // Keep this
    private var configManager = ConfigManager.shared  // Keep reference if needed often

    // Add property for the notification controller
    private var sequenceNotificationController: SequenceNotificationController?

    // MARK: - State
    private var hasAccessibilityPermissions: Bool = false
    private var isWaitingForPermissions: Bool = false
    private var isEnabled: Bool = true  // Track enabled state for menu

    // MARK: - NSApplicationDelegate Methods
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("HyprCuts App finished launching!")

        checkAccessibilityPermissions()

        // Initialize Action Executor
        actionExecutor = ActionExecutor()

        setupMenuBar()  // Setup initial menu bar

        // Initialize Keyboard Monitor and Notification Controller *only if* permissions are granted
        if hasAccessibilityPermissions {
            initializeMonitors()
        } else {
            logger.warning("Keyboard Monitor not started. Waiting for Accessibility permissions.")
            // The menu bar icon/state will be updated later if needed
        }
        updateMenuBarState()  // Initial update based on state

        // Register for config reloaded notifications to update menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidReload),
            name: ConfigManager.configReloadedNotification,
            object: nil
        )
        // Register for Harpoon pairings change notifications (Task 41e)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarState),  // Reuse the same selector
            name: HarpoonManager.pairingsDidChangeNotification,
            object: nil
        )
    }

    // Called when the app becomes active (e.g., returning from System Settings)
    func applicationDidBecomeActive(_ notification: Notification) {
        logger.debug("Application became active.")
        // Note: Permission checking after prompt is now handled by the timer polling mechanism.
        // This method remains for other potential activation tasks.
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("HyprCuts App will terminate.")
        // Stop the keyboard monitor
        keyboardMonitor?.stop()
        // Stop the timer if it's running
        permissionPollTimer?.invalidate()
        // Clean up notification controller
        sequenceNotificationController = nil  // This will trigger deinit
        // Remove observer
        NotificationCenter.default.removeObserver(
            self, name: ConfigManager.configReloadedNotification, object: nil)
        // Remove Harpoon observer
        NotificationCenter.default.removeObserver(
            self, name: HarpoonManager.pairingsDidChangeNotification, object: nil)
    }

    // MARK: - Initialization Helpers
    // Renamed for clarity
    private func initializeMonitors() {
        guard keyboardMonitor == nil else {
            logger.debug("Monitors already initialized.")
            return
        }
        guard hasAccessibilityPermissions else {
            logger.warning("Cannot initialize monitors without Accessibility permissions.")
            return
        }
        logger.info("Initializing Monitors...")

        // Ensure we have an actionExecutor instance
        guard let executor = self.actionExecutor else {
            logger.error("ActionExecutor not initialized before KeyboardMonitor.")
            return
        }

        // Init KeyboardMonitor
        logger.debug("Initializing Keyboard Monitor...")
        let monitor = KeyboardMonitor(actionExecutor: executor)
        self.keyboardMonitor = monitor

        // Init Notification Controller AFTER monitor is created
        logger.debug("Initializing Sequence Notification Controller...")
        self.sequenceNotificationController = SequenceNotificationController(
            keyboardMonitor: monitor)

        // Start KeyboardMonitor AFTER controller is set up
        logger.info("Starting Keyboard Monitor...")
        if isEnabled {  // Only start if the app is conceptually enabled
            monitor.start()
        } else {
            logger.info("Keyboard monitor initialized but not started (App is disabled).")
        }
    }

    // MARK: - Accessibility Permissions
    @objc private func pollForPermissions() {
        logger.debug("Polling for accessibility permissions...")
        let checkOptions: [String: Bool] = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false
        ]
        let currentlyTrusted = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)

        if currentlyTrusted {
            logger.info("Permissions granted during polling.")
            hasAccessibilityPermissions = true
            isWaitingForPermissions = false

            // Stop the timer
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil

            // Start the monitors if they weren't already (this will also init the controller)
            if keyboardMonitor == nil {
                initializeMonitors()
            }
            updateMenuBarState()  // Update menu state (icon, items)

        } else {
            logger.debug("Permissions still not granted.")
            // Keep polling
        }
    }

    private func checkAccessibilityPermissions() {
        // Check if the app is already trusted *without* prompting initially
        let checkOptions: [String: Bool] = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false
        ]
        hasAccessibilityPermissions = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)

        if hasAccessibilityPermissions {
            logger.info("Accessibility permissions granted.")
            permissionPollTimer?.invalidate()  // Stop polling if manually re-checked and OK
            permissionPollTimer = nil
            isWaitingForPermissions = false
            // TODO: Update UI to normal state if it was previously showing a warning (Task 28)
        } else {
            logger.warning("Accessibility permissions not granted. Prompting user.")
            isWaitingForPermissions = true
            // Prompt the user to grant permissions. This opens the system dialog.
            let promptOptions: [String: Bool] = [
                kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
            ]
            _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
            // Don't re-check here. Will check again in applicationDidBecomeActive.
            // Instead, start a timer to poll for permission changes.
            if permissionPollTimer == nil {
                logger.info("Starting timer to poll for permissions...")
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
        updateMenuBarState()  // Update menu state after check
    }

    // MARK: - Menu Bar Setup & State
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            // Set initial icon - updated in updateMenuBarState
            button.image = NSImage(
                systemSymbolName: "keyboard.slash",
                accessibilityDescription: "HyprCuts (Requires Permissions)")
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        constructMenu()  // Build the menu structure
        statusItem?.menu = menu  // Assign the menu
    }

    // Rebuilds the menu content (titles, states)
    @objc private func constructMenu() {
        let menu = self.menu ?? NSMenu()  // Reuse existing menu or create new
        menu.removeAllItems()  // Clear existing items before rebuilding

        // --- Enable/Disable Toggle --- (Task 27a)
        let enableDisableTitle = isEnabled ? "Disable HyprCuts" : "Enable HyprCuts"
        let enableDisableItem = NSMenuItem(
            title: enableDisableTitle, action: #selector(toggleEnable(_:)), keyEquivalent: "")
        enableDisableItem.state = isEnabled ? .on : .off  // Show checkmark when enabled
        enableDisableItem.isEnabled = hasAccessibilityPermissions  // Can only toggle if permissions OK
        menu.addItem(enableDisableItem)

        menu.addItem(NSMenuItem.separator())

        // --- Restart --- (Task 27b)
        menu.addItem(
            NSMenuItem(title: "Restart", action: #selector(restartApp(_:)), keyEquivalent: ""))

        // --- Reload Config --- (Task 27c)
        let reloadItem = NSMenuItem(
            title: "Reload Config", action: #selector(reloadConfig(_:)), keyEquivalent: "")
        reloadItem.isEnabled = hasAccessibilityPermissions && isEnabled  // Only if enabled & permissions OK
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())

        // --- Display Master Key --- (Task 27d)
        let masterKeyName = configManager.getMasterKeyDisplayString() ?? "(Not Set)"
        let masterKeySymbol = KeyMapping.getDisplayString(for: masterKeyName)
        let masterKeyItem = NSMenuItem(
            title: "Master Key: \(masterKeySymbol) (\(masterKeyName))", action: nil,
            keyEquivalent: "")  // Show both symbol and name
        masterKeyItem.isEnabled = false
        menu.addItem(masterKeyItem)

        // --- Harpoon Pairings Section --- (Task 41)
        menu.addItem(NSMenuItem.separator())  // Separator before harpoon section

        let pairingsTitleItem = NSMenuItem(
            title: "Harpoon Pairings:", action: nil, keyEquivalent: "")
        pairingsTitleItem.isEnabled = false  // Just a title
        menu.addItem(pairingsTitleItem)

        let harpoonPairings = HarpoonManager.shared.getAllPairings()

        if harpoonPairings.isEmpty {
            // Task 41d: Show "(None)" if no pairings
            let noneItem = NSMenuItem(title: "  (None)", action: nil, keyEquivalent: "")
            noneItem.isEnabled = false
            menu.addItem(noneItem)
        } else {
            // Task 41b, 41c: List each pairing
            // Sort by slot key for consistent order
            for (slotKey, bundleId) in harpoonPairings.sorted(by: { $0.key < $1.key }) {
                // Resolve app name from bundle ID
                var appName = bundleId  // Default to bundle ID if name lookup fails
                if let appURL = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: bundleId),
                    let appBundle = Bundle(url: appURL),
                    let name = appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                {
                    appName = name
                }

                let pairingItem = NSMenuItem(
                    title: "  Slot '\(slotKey)': \(appName)", action: nil, keyEquivalent: "")
                pairingItem.isEnabled = false  // Informational only
                menu.addItem(pairingItem)
            }
        }

        menu.addItem(NSMenuItem.separator())  // Separator after harpoon section

        // --- Quit --- (Task 27e)
        menu.addItem(
            NSMenuItem(
                title: "Quit HyprCuts", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))

        self.menu = menu  // Store the updated menu
        statusItem?.menu = menu  // Re-assign to status item if needed
    }

    // MARK: - Helper Functions
    // Removed custom getMasterKeySymbol function, using KeyMapping.getDisplayString instead.

    // Updates the menu bar icon and rebuilds menu content based on current state
    @objc private func updateMenuBarState() {
        DispatchQueue.main.async {  // Ensure UI updates happen on main thread
            let imageName: String
            let accessibilityDescription: String

            if !self.hasAccessibilityPermissions {
                imageName = "keyboard.slash"  // Icon indicating permissions needed
                accessibilityDescription = "HyprCuts (Requires Permissions)"
            } else if !self.isEnabled {
                imageName = "keyboard.badge.ellipsis"  // Icon indicating disabled
                accessibilityDescription = "HyprCuts (Disabled)"
            } else {
                imageName = "keyboard.fill"  // Normal enabled icon
                accessibilityDescription = "HyprCuts (Enabled)"
            }

            if let button = self.statusItem?.button {
                button.image = NSImage(
                    systemSymbolName: imageName, accessibilityDescription: accessibilityDescription)
            }

            // Rebuild the menu to reflect the current state (Enable/Disable title, item states)
            self.constructMenu()
        }
    }

    // Action triggered by clicking the status bar item button
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        logger.debug("Status bar button clicked. Default menu should appear if set.")
    }

    // --- Menu Actions --- (Task 27)

    @objc func toggleEnable(_ sender: NSMenuItem) {
        logger.debug("Toggle Enable/Disable action triggered")
        isEnabled.toggle()
        logger.info("HyprCuts is now \(self.isEnabled ? "Enabled" : "Disabled")")

        if isEnabled {
            // If enabling, ensure monitors are initialized and started
            if keyboardMonitor == nil {
                initializeMonitors()
            } else {
                keyboardMonitor?.start()
            }
        } else {
            // If disabling, stop the keyboard monitor
            keyboardMonitor?.stop()
        }

        updateMenuBarState()  // Update icon and menu item title/state
    }

    @objc func restartApp(_ sender: Any?) {
        logger.info("Restart action triggered")
        // Simple restart implementation
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let url = URL(fileURLWithPath: resourcePath)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            logger.error("Error restarting application: \(error.localizedDescription)")
            // TODO: Show error to user?
        }
    }

    @objc func reloadConfig(_ sender: Any?) {
        logger.info("Reload Config action triggered")
        configManager.reloadConfig()  // This posts the notification handled below
    }

    // Called when ConfigManager posts notification
    @objc private func configDidReload() {
        logger.debug("AppDelegate received config reload notification.")
        // Update keyboard monitor with new config values
        keyboardMonitor?.updateConfigValues()
        // Update menu bar state (e.g., master key display)
        updateMenuBarState()
        // Sequence notification controller updates via its own observer
    }
}
