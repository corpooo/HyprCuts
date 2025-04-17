import SwiftUI
import CoreGraphics

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
    private var menu: NSMenu? // Keep track of the menu
    // Potential popover reference if using SwiftUI for menu UI later
    // private var popover: NSPopover?

    // MARK: - Event Tap Properties
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var masterKeyCode: CGKeyCode = 39 // Placeholder: Single Quote (') key code

    // State for Tap vs Hold detection
    private var isMasterKeyDown = false             // True ONLY if master key is confirmed HELD
    // Store info about the initial down event to replay on tap
    private var pendingMasterKeyDownCode: CGKeyCode? = nil
    private var pendingMasterKeyDownFlags: CGEventFlags? = nil
    private var masterKeyDownTimestamp: Date? = nil  // When master key was pressed
    private var masterKeyHeldTimer: Timer? = nil     // Timer to detect hold
    private var isMasterKeyHeldProcessing = false   // True between master keyDown and timer fire/keyUp
    // TODO: Replace with actual value from config loading (Task 10)
    private var tapTimeoutMs: Int = 200            // Milliseconds to differentiate tap/hold

    // MARK: - NSApplicationDelegate Methods
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("HyprCuts App finished launching!")
        setupMenuBar()
        setupEventTap() // <-- Set up the event tap

        // TODO: Initialize Keyboard Monitor
        // TODO: Initialize Config Manager (Load initial config)
        // TODO: Check Accessibility Permissions
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("HyprCuts App will terminate.")
        // TODO: Perform any necessary cleanup
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

    // MARK: - Event Tap Setup & Handling

    private func setupEventTap() {
        // Define the event tap callback closure inline for capturing `self`
        let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            // `refcon` holds the `self` reference passed during tap creation.
            // We need to safely unwrap it.
            guard let refcon = refcon else {
                print("Error: refcon is nil in event tap callback")
                // Pass the event through if we can't get self
                return Unmanaged.passRetained(event)
            }
            let mySelf = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

            // Check if the event is a key event (keyDown or keyUp only)
            guard type == .keyDown || type == .keyUp else {
                // Ignore other event types like flagsChanged, mouse events, etc.
                return Unmanaged.passRetained(event)
            }

            guard let keyEvent = NSEvent(cgEvent: event) else {
                print("Error converting CGEvent to NSEvent for key event")
                return Unmanaged.passRetained(event)
            }
            let keyCode = CGKeyCode(keyEvent.keyCode)
            // print("Detected key event - Code: \(keyCode), Type: \(type.rawValue)") // <-- REMOVING debug print

            // Check if it's the master key
            if keyCode == mySelf.masterKeyCode {
                if type == .keyDown {
                    // If master key is already confirmed held, or we are already processing a press, ignore repeat keyDowns
                    if mySelf.isMasterKeyDown || mySelf.isMasterKeyHeldProcessing {
                         // print("Ignoring repeat Master key DOWN event.")
                         return nil // Suppress repeat down events
                    }

                    // print("Master key DOWN (potential tap/hold)")
                    // Store the necessary info from the event
                    mySelf.pendingMasterKeyDownCode = keyCode
                    mySelf.pendingMasterKeyDownFlags = event.flags
                    mySelf.isMasterKeyHeldProcessing = true
                    mySelf.masterKeyDownTimestamp = Date()

                    // Invalidate any existing timer just in case
                    mySelf.masterKeyHeldTimer?.invalidate()

                    // Start the timer to detect a hold
                    mySelf.masterKeyHeldTimer = Timer.scheduledTimer(
                        timeInterval: Double(mySelf.tapTimeoutMs) / 1000.0,
                        target: mySelf,
                        selector: #selector(mySelf.masterKeyHeldTimerFired(_:)),
                        userInfo: nil,
                        repeats: false
                    )

                    // print("Suppressing initial Master key DOWN event.")
                    return nil // <-- Changed from passRetained

                } else { // .keyUp
                    // print("Master key UP received.")
                    // Was this the keyUp for our potential tap/hold?
                    if mySelf.isMasterKeyHeldProcessing {
                        // KeyUp happened *before* the timer fired - it's a TAP
                        // print("Detected Master key TAP.")
                        mySelf.masterKeyHeldTimer?.invalidate() // Cancel the timer
                        mySelf.masterKeyHeldTimer = nil
                        mySelf.isMasterKeyHeldProcessing = false // Done processing

                        // Re-post the down/up events for the tap, temporarily disabling our tap
                        if let downCode = mySelf.pendingMasterKeyDownCode, let currentTap = mySelf.eventTap {
                            let downFlags = mySelf.pendingMasterKeyDownFlags ?? CGEventFlags() // Use stored flags or default
                            let upFlags = event.flags // Use flags from the actual keyUp event

                            // print("Disabling event tap temporarily to replay TAP events.")
                            CGEvent.tapEnable(tap: currentTap, enable: false)

                            // Synthesize and post events using the helper
                            mySelf.postSynthesizedKeyEvent(keyCode: downCode, keyDown: true, flags: downFlags)
                            mySelf.postSynthesizedKeyEvent(keyCode: downCode, keyDown: false, flags: upFlags)

                            // print("Re-enabling event tap.")
                            CGEvent.tapEnable(tap: currentTap, enable: true)

                            // Clear stored info
                            mySelf.pendingMasterKeyDownCode = nil
                            mySelf.pendingMasterKeyDownFlags = nil
                        } else {
                            // print("Warning: Master key TAP detected, but no stored key code or event tap found to replay.")
                        }

                        // Suppress the original keyUp event in the callback, as we manually synthesized it.
                        // print("Suppressing original Master key UP event callback for TAP.")
                        return nil
                    } else if mySelf.isMasterKeyDown {
                        // KeyUp happened *after* the timer fired - it's the end of a HOLD
                        // print("Master key HELD released.")
                        mySelf.isMasterKeyDown = false // No longer held
                        // Clear stored info
                        mySelf.pendingMasterKeyDownCode = nil
                        mySelf.pendingMasterKeyDownFlags = nil
                        // TODO: Process completed sequence or timeout (Task 1b, 16)
                        // TODO: Hide sequence input UI if configured
                        // Suppress the keyUp event since it was part of a hold sequence
                        // print("Suppressing Master key UP event for HOLD.")
                        return nil
                    } else {
                        // Master key was not held or being processed (e.g., keyUp without prior keyDown?). Let it pass.
                        // print("Passing through unexpected Master key UP event.")
                        return Unmanaged.passRetained(event)
                    }
                }
            } else {
                // It's not the master key
                if mySelf.isMasterKeyDown {
                    // Master key is confirmed HELD, this is part of a sequence
                    if type == .keyDown {
                         // print("Sequence key DOWN: \(keyCode)")
                         // TODO: Handle sequence input (Task 1b, 17)
                    }
                    // Suppress other keys (down and up) while master key is held
                    // print("Suppressing sequence key event (Code: \(keyCode), Type: \(type.rawValue))")
                    return nil
                } else {
                    // Master key is not held, let other keys pass through
                    return Unmanaged.passRetained(event)
                }
            }
        }

        // Specify the events to listen for: key down and key up ONLY
        let eventsOfInterest: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                           (1 << CGEventType.keyUp.rawValue)

        // Pass `self` as the refcon parameter. We need to manage its memory manually.
        let OpaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        // Create the event tap.
        // Note: This requires Accessibility permissions. Will fail without them. (See Task 3, 4)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, // Captures events system-wide at the session level
            place: .headInsertEventTap, // Inserted before other taps
            options: .defaultTap, // Default behavior
            eventsOfInterest: eventsOfInterest,
            callback: eventTapCallback,
            userInfo: OpaqueSelf // Pass self reference here
        )

        guard let eventTap = eventTap else {
            print("FATAL: Failed to create event tap. Check Accessibility Permissions.")
            // TODO: Handle this error robustly (Task 4, 12, 28)
            // Consider showing an alert or updating the menu bar icon.
            // For now, we might just exit or disable functionality.
            // NSApp.terminate(nil) // Or disable functionality
            return
        }
        print("Event tap created successfully.")

        // Create a run loop source and add it to the current run loop.
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
             print("FATAL: Failed to create run loop source.")
             CFMachPortInvalidate(eventTap)
             self.eventTap = nil
             // NSApp.terminate(nil) // Or disable functionality
             return
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        print("Event tap added to run loop.")

        // Enable the event tap.
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("Event tap enabled.")
    }

    // Called by the masterKeyHeldTimer when the tapTimeoutMs is exceeded
    @objc private func masterKeyHeldTimerFired(_ timer: Timer) {
        // print("Master key hold timer fired.")
        masterKeyHeldTimer = nil // Timer has done its job
        // Discard the stored event info, it's a hold
        pendingMasterKeyDownCode = nil
        pendingMasterKeyDownFlags = nil

        // Only proceed if the key is still considered potentially held
        if isMasterKeyHeldProcessing {
            // print("Confirmed Master key HELD (timer). Entering active state.")
            isMasterKeyDown = true           // Master key is officially HELD
            isMasterKeyHeldProcessing = false // Done processing the hold detection
            // TODO: Start sequence listening (Task 1b)
            // TODO: Show sequence input UI if configured
        } else {
             // print("Hold timer fired, but key already released or processed. Ignoring.")
        }
    }

    // Helper function to synthesize and post key events
    private func postSynthesizedKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("Error: Failed to create event source for synthesizing key event.")
            return
        }
        guard let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            print("Error: Failed to create keyboard event for synthesizing.")
            return
        }
        keyEvent.flags = flags
        // Post back to the session tap location - this is safe because we disable our tap before calling this
        keyEvent.post(tap: .cgSessionEventTap)
        // print("Posted synthesized key event to Session Tap (KeyDown: \(keyDown), Code: \(keyCode), Flags: \(flags.rawValue))")
    }
}
