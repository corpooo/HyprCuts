//
//  KeyboardMonitor.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import AppKit  // Needed for NSEvent
import CoreGraphics
import Foundation

class KeyboardMonitor {

  // MARK: - Constants
  // Define the modifier flags we care about for matching sequences
  static let relevantModifierFlags: CGEventFlags = [
    .maskShift,
    .maskControl,
    .maskAlternate,  // Option key
    .maskCommand,
    .maskSecondaryFn,  // Function key (Fn)
    .maskAlphaShift,  // Caps Lock
    // We explicitly EXCLUDE .maskNonCoalesced, .maskNumericPad etc.
  ]

  // MARK: - Dependencies
  private let actionExecutor = ActionExecutor()

  // MARK: - Event Tap Properties
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var configuredMasterKeyCode: CGKeyCode?  // Loaded from config
  private var configuredTapTimeoutMs: Int = 200  // Default to 200ms initially

  // State for Tap vs Hold detection
  private var isMasterKeyDown = false  // True ONLY if master key is confirmed HELD
  // Store info about the initial down event to replay on tap
  private var pendingMasterKeyDownCode: CGKeyCode? = nil
  private var pendingMasterKeyDownFlags: CGEventFlags? = nil
  private var masterKeyDownTimestamp: Date? = nil  // When master key was pressed
  private var masterKeyHeldTimer: Timer? = nil  // Timer to detect hold
  private var isMasterKeyHeldProcessing = false  // True between master keyDown and timer fire/keyUp

  // State for Sequence detection
  private var currentSequence: [(keyCode: CGKeyCode, modifiers: CGEventFlags)] = []
  private var sequenceActionTriggered = false  // Flag to indicate a sequence completed and triggered an action

  // TODO: Replace with actual value from config loading (Task 10)
  // private var tapTimeoutMs: Int = 200  // Milliseconds to differentiate tap/hold

  // TODO: Add delegate/callback for sequence detection

  init() {
    // Load initial config values
    updateConfigValues()
  }

  deinit {
    stop()  // Ensure the tap is disabled when the monitor is deinitialized
  }

  func start() {
    print("Starting Keyboard Monitor...")
    setupEventTap()
  }

  func stop() {
    print("Stopping Keyboard Monitor...")
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      if let runLoopSource = runLoopSource {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.runLoopSource = nil  // Release reference
      }
      // CFMachPortInvalidate(eventTap) // This might be needed but test first
      self.eventTap = nil  // Release reference
      print("Event tap disabled and removed from run loop.")
    }
    masterKeyHeldTimer?.invalidate()
    masterKeyHeldTimer = nil
  }

  // MARK: - Event Tap Setup & Handling

  private func setupEventTap() {
    // Check if already running
    guard eventTap == nil else {
      print("Event tap already configured.")
      return
    }

    // Define the event tap callback closure inline for capturing `self`
    let eventTapCallback: CGEventTapCallBack = {
      proxy, type, event, refcon -> Unmanaged<CGEvent>? in
      // `refcon` holds the `self` reference passed during tap creation.
      // We need to safely unwrap it.
      guard let refcon = refcon else {
        print("Error: refcon is nil in event tap callback")
        // Pass the event through if we can't get self
        return Unmanaged.passRetained(event)
      }
      let mySelf = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()

      // Check if the event is a key event (keyDown or keyUp only)
      guard type == .keyDown || type == .keyUp else {
        // Ignore other event types like flagsChanged, mouse events, etc.
        return Unmanaged.passRetained(event)
      }

      // Ensure we have a valid master key configured
      guard let targetMasterKeyCode = mySelf.configuredMasterKeyCode else {
        // print("KeyboardMonitor: No valid master key configured. Passing event through.")
        return Unmanaged.passRetained(event)
      }

      // Use AppKit's NSEvent for easier key code access
      guard let nsEvent = NSEvent(cgEvent: event) else {
        print("Error converting CGEvent to NSEvent for key event")
        return Unmanaged.passRetained(event)
      }
      let keyCode = CGKeyCode(nsEvent.keyCode)
      // print("Detected key event - Code: \(keyCode), Type: \(type.rawValue)")

      // Check if it's the configured master key
      if keyCode == targetMasterKeyCode {
        if type == .keyDown {
          // If master key is already confirmed held, or we are already processing a press, ignore repeat keyDowns
          if mySelf.isMasterKeyDown || mySelf.isMasterKeyHeldProcessing {
            // print("Ignoring repeat Master key DOWN event.")
            return nil  // Suppress repeat down events
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
          // Use the configured tap timeout directly (default handled by ConfigManager)
          let timeout = Double(mySelf.configuredTapTimeoutMs) / 1000.0
          mySelf.masterKeyHeldTimer = Timer.scheduledTimer(
            timeInterval: timeout,
            target: mySelf,
            selector: #selector(mySelf.masterKeyHeldTimerFired(_:)),
            userInfo: nil,
            repeats: false
          )

          // print("Suppressing initial Master key DOWN event.")
          return nil  // Suppress the initial down event

        } else {  // .keyUp
          // print("Master key UP received.")
          // Was this the keyUp for our potential tap/hold?
          if mySelf.isMasterKeyHeldProcessing {
            // KeyUp happened *before* the timer fired - it's a TAP
            // print("Detected Master key TAP.")
            mySelf.masterKeyHeldTimer?.invalidate()  // Cancel the timer
            mySelf.masterKeyHeldTimer = nil
            mySelf.isMasterKeyHeldProcessing = false  // Done processing

            // Re-post the down/up events for the tap, temporarily disabling our tap
            if let downCode = mySelf.pendingMasterKeyDownCode, let currentTap = mySelf.eventTap {
              let downFlags = mySelf.pendingMasterKeyDownFlags ?? CGEventFlags()  // Use stored flags or default
              let upFlags = event.flags  // Use flags from the actual keyUp event

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
            mySelf.isMasterKeyDown = false  // No longer held
            // Clear stored info
            mySelf.pendingMasterKeyDownCode = nil
            mySelf.pendingMasterKeyDownFlags = nil

            // Reset the flag indicating an action was triggered by this sequence
            mySelf.sequenceActionTriggered = false

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
            // Get keycode and flags for the incoming key
            let sequenceKeyCode = CGKeyCode(nsEvent.keyCode)
            let sequenceFlags = event.flags  // Use the raw flags from the CGEvent

            // Append to the current sequence
            mySelf.currentSequence.append((keyCode: sequenceKeyCode, modifiers: sequenceFlags))
            // print("Added to sequence: \(mySelf.currentSequence.last!), Current full: \(mySelf.currentSequence)")

            // Process the updated sequence
            mySelf.processCurrentSequence()

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
    let eventsOfInterest: CGEventMask =
      (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

    // Pass `self` as the refcon parameter. We need to manage its memory manually.
    let OpaqueSelf = Unmanaged.passUnretained(self).toOpaque()

    // Create the event tap.
    // Note: This requires Accessibility permissions. Will fail without them. (See Task 3, 4)
    eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,  // Captures events system-wide at the session level
      place: .headInsertEventTap,  // Inserted before other taps
      options: .defaultTap,  // Default behavior
      eventsOfInterest: eventsOfInterest,
      callback: eventTapCallback,
      userInfo: OpaqueSelf  // Pass self reference here
    )

    guard let eventTap = eventTap else {
      print("FATAL: Failed to create event tap. Check Accessibility Permissions.")
      // TODO: Handle this error robustly (Task 4, 12, 28) - Maybe via delegate/notification
      // Consider showing an alert or updating the menu bar icon via AppDelegate.
      return
    }
    print("Event tap created successfully.")

    // Create a run loop source and add it to the current run loop.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    guard let runLoopSource = runLoopSource else {
      print("FATAL: Failed to create run loop source.")
      CFMachPortInvalidate(eventTap)  // Clean up the tap
      self.eventTap = nil
      // TODO: Handle this error robustly - Maybe via delegate/notification
      return
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    print("Event tap added to run loop.")

    // Enable the event tap.
    CGEvent.tapEnable(tap: eventTap, enable: true)
    print("Event tap enabled.")
  }

  // MARK: - Configuration Handling

  /// Updates the monitor's behavior based on the current ConfigManager state.
  private func updateConfigValues() {
    print("KeyboardMonitor: Updating config values...")
    // Reset state that depends on config
    self.configuredMasterKeyCode = nil
    self.isMasterKeyDown = false
    self.isMasterKeyHeldProcessing = false
    self.masterKeyHeldTimer?.invalidate()
    self.currentSequence = []
    self.sequenceActionTriggered = false

    if let masterKeyString = ConfigManager.shared.getMasterKey() {
      self.configuredMasterKeyCode = KeyMapping.getKeyCode(for: masterKeyString)
    } else {
      print("KeyboardMonitor: Master key not found in config.")
    }
    self.configuredTapTimeoutMs = ConfigManager.shared.getMasterKeyTapTimeout()

    print(
      "KeyboardMonitor: Config updated. MasterKeyCode: \(String(describing: configuredMasterKeyCode)), TapTimeout: \(configuredTapTimeoutMs)ms"
    )

    // If the tap is already running, potentially restart it if master key changed?
    // For now, assumes restart happens externally if needed.
  }

  /// Called when the configuration has potentially changed.
  func configDidChange() {
    print("KeyboardMonitor: Configuration change detected, updating values...")
    updateConfigValues()
    // TODO: Reset sequence state if master key changed?
  }

  // Called by the masterKeyHeldTimer when the tapTimeoutMs is exceeded
  @objc private func masterKeyHeldTimerFired(_ timer: Timer) {
    // Timer fired, meaning the key was held down long enough
    masterKeyHeldTimer = nil  // Timer is non-repeating
    if isMasterKeyHeldProcessing {
      // print("Master key HELD confirmed.")
      isMasterKeyDown = true  // Set the state to indicate master key is officially held
      isMasterKeyHeldProcessing = false  // Done with initial processing

      // Reset sequence state when hold begins
      currentSequence = []
      sequenceActionTriggered = false

      // TODO: Show sequence input UI if configured
      // TODO: Notify delegate/callback about sequence start

      // Since the original keyDown was suppressed, we don't need to do anything else here.
      // The subsequent key events will be handled based on isMasterKeyDown.
    }
  }

  // MARK: - Sequence Processing (Task 17)

  private func processCurrentSequence() {
    guard !currentSequence.isEmpty else { return }
    // print("Processing sequence: \(currentSequence)")

    guard let bindings = ConfigManager.shared.getBindings() else {
      print("No bindings loaded, cannot process sequence.")
      return
    }

    var potentialMatches = 0
    var exactMatchBinding: Binding? = nil

    for binding in bindings {
      guard let parsedKeys = binding.parsedKeys else { continue }  // Skip bindings that failed parsing

      // Check if currentSequence is a prefix of this binding's parsedKeys
      // Use a custom comparison that ignores irrelevant modifier flags
      if parsedKeys.starts(
        with: currentSequence,
        by: { bindingKey, sequenceKey in
          // Compare key codes
          let keyCodesMatch = bindingKey.keyCode == sequenceKey.keyCode
          // Compare relevant modifier flags
          // Intersect the incoming sequence key's flags with the relevant ones
          let sequenceRelevantFlags = sequenceKey.modifiers.intersection(
            KeyboardMonitor.relevantModifierFlags)
          // The binding key's flags should already only contain relevant ones from parsing
          let bindingFlags = bindingKey.modifiers
          let modifiersMatch = sequenceRelevantFlags == bindingFlags

          // print("Comparing BK: \(bindingKey) with SK: \(sequenceKey) -> KC Match: \(keyCodesMatch), Mod Match: \(modifiersMatch) (SeqRel: \(sequenceRelevantFlags.rawValue), Bind: \(bindingFlags.rawValue))")

          return keyCodesMatch && modifiersMatch
        })
      {
        // It's a potential match (either exact or prefix)
        potentialMatches += 1
        // print("Potential match with binding: \(binding.description ?? "N/A")")

        if parsedKeys.count == currentSequence.count {
          // Exact match found!
          if exactMatchBinding != nil {
            // This shouldn't happen if validation prevents duplicate full sequences
            print(
              "WARNING: Multiple exact matches found for sequence! Using the first one found: \(exactMatchBinding!.description ?? "N/A")"
            )
          } else {
            exactMatchBinding = binding
            // print("Exact match found: \(binding.description ?? "N/A")")
          }
          // Don't break here, continue checking other bindings in case of ambiguities or errors
        }
      }
    }

    if let bindingToExecute = exactMatchBinding {
      print("Executing action for binding: \(bindingToExecute.description ?? "No description")")
      // TODO: Execute the action associated with the binding (Task 1b, 20-24)
      // mySelf.actionExecutor.execute(action: bindingToExecute.action)

      // Mark that an action was triggered
      sequenceActionTriggered = true

      // Reset sequence immediately after execution? Or wait for master key up?
      // Resetting immediately prevents issues if user keeps typing after match.
      currentSequence = []
      // print("Sequence reset after action execution.")

      // TODO: Provide feedback (e.g., success notification)? (Task 27)

    } else if potentialMatches > 0 {
      // It's a prefix of one or more bindings, but not an exact match yet.
      // Do nothing, wait for the next key or timeout.
      // The sequence timer is already running or will be started by the caller.
    } else {
      // No potential matches found (neither prefix nor exact).
      // The sequence is invalid.
      // print("Invalid sequence: \(currentSequence)")
      // Reset the sequence
      currentSequence = []
      sequenceActionTriggered = false  // Ensure reset

      // TODO: Provide feedback (e.g., error notification, visual cue)? (Task 18, 27b)
    }
  }

  // MARK: - Helpers

  // Helper function to synthesize and post key events
  private func postSynthesizedKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      print("Error: Failed to create event source for synthesizing key event.")
      return
    }
    guard let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
    else {
      print("Error: Failed to create keyboard event for synthesizing.")
      return
    }
    keyEvent.flags = flags
    // Post back to the session tap location - this is safe because we disable our tap before calling this
    keyEvent.post(tap: .cgSessionEventTap)
    // print("Posted synthesized key event to Session Tap (KeyDown: \(keyDown), Code: \(keyCode), Flags: \(flags.rawValue))")
  }
}
