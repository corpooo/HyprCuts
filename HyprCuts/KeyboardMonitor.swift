//
//  KeyboardMonitor.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import AppKit  // Needed for NSEvent
import CoreGraphics
import Foundation
import SwiftUI  // Add this import for ObservableObject

// Conform to ObservableObject
class KeyboardMonitor: ObservableObject {

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
  private let actionExecutor: ActionExecutor
  private let configManager = ConfigManager.shared  // Access config

  // MARK: - Event Tap Properties
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var configuredMasterKeyCode: CGKeyCode?  // Loaded from config
  private var configuredTapTimeoutMs: Int = 200  // Default to 200ms initially

  // State for Tap vs Hold detection
  @Published var isMasterKeyDown = false  // Publish this state
  // Store info about the initial down event to replay on tap
  private var pendingMasterKeyDownCode: CGKeyCode? = nil
  private var pendingMasterKeyDownFlags: CGEventFlags? = nil
  private var masterKeyDownTimestamp: Date? = nil  // When master key was pressed
  private var masterKeyHeldTimer: Timer? = nil  // Timer to detect hold
  private var isMasterKeyHeldProcessing = false  // True between master keyDown and timer fire/keyUp

  // MARK: - v2 Sequence State
  private var rootBindings: [String: BindingNode]? = nil  // Store the root of the bindings tree
  private var currentBindingNode: BindingNode? = nil  // Current node in the binding tree (nil = root)
  @Published var currentBindingPath: [String] = []  // Publish this state

  // TODO: Replace with actual value from config loading (Task 10)
  // private var tapTimeoutMs: Int = 200  // Milliseconds to differentiate tap/hold

  // TODO: Add delegate/callback for sequence detection

  // MARK: - Callbacks
  var onSequenceCompleted: (([String]) -> Void)?  // Callback for successful sequence completion

  init(actionExecutor: ActionExecutor) {
    self.actionExecutor = actionExecutor
    // Load initial config values
    updateConfigValues()
  }

  deinit {
    stop()  // Ensure the tap is disabled when the monitor is deinitialized
    // TODO: Potentially add notification if no binding matches
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
          print("DEBUG: Starting master key hold timer with timeout: \(timeout)s")
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

            // Reset v2 sequence state if tap occurs unexpectedly during processing
            mySelf.resetSequenceStateInternal()

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

              // Reset v2 sequence state if tap occurs unexpectedly during processing
              // This also ensures the published path is cleared
              mySelf.resetSequenceStateInternal()

              // Suppress the original keyUp event in the callback, as we manually synthesized it.
              // print("Suppressing original Master key UP event callback for TAP.")
              return nil
            } else {
              // print("Warning: Master key TAP detected, but no stored key code or event tap found to replay.")
            }

            // Suppress the original keyUp event in the callback, as we manually synthesized it.
            // print("Suppressing original Master key UP event callback for TAP.")
            return nil
          } else if mySelf.isMasterKeyDown {
            // KeyUp happened *after* the timer fired - it's the end of a HOLD
            // print("Master key HELD released.")
            mySelf.isMasterKeyDown = false  // No longer held <-- Update published state
            print("DEBUG: Master key released (Hold ended). Resetting sequence state.")
            // Clear stored info
            mySelf.pendingMasterKeyDownCode = nil
            mySelf.pendingMasterKeyDownFlags = nil

            // Reset v2 sequence state on master key release
            mySelf.resetSequenceStateInternal()  // <-- This clears the published path

            // We still suppress the original master key up event
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
            // Convert the pressed key event to its string representation
            if let keyString = mySelf.keyStringFromEvent(event) {
              print("DEBUG: Sequence Key Down: \(keyString)")
              mySelf.processSequenceKey(keyString: keyString)
            } else {
              print("WARN: Could not get string representation for key code \(keyCode)")
              // Optionally provide feedback for unrecognized keys
            }
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
  func updateConfigValues() {
    print("KeyboardMonitor: Updating config values...")
    // Reset state that depends on config
    self.configuredMasterKeyCode = nil
    self.isMasterKeyDown = false
    self.isMasterKeyHeldProcessing = false
    self.masterKeyHeldTimer?.invalidate()
    self.currentBindingNode = nil
    self.currentBindingPath = []

    let configManager = ConfigManager.shared
    if let masterKeyString = configManager.getMasterKey(),
      let code = KeyMapping.getKeyCode(for: masterKeyString)
    {
      self.configuredMasterKeyCode = code
    } else {
      print("KeyboardMonitor: Master key not found in config.")
    }
    self.configuredTapTimeoutMs = configManager.getMasterKeyTapTimeout()

    // Load the v2 bindings tree
    self.rootBindings = configManager.getBindings()
    if self.rootBindings == nil || self.rootBindings!.isEmpty {
      print("KeyboardMonitor: WARNING - No bindings loaded or bindings are empty.")
    }

    print(
      "KeyboardMonitor: Config updated. MasterKeyCode: \(String(describing: configuredMasterKeyCode)), TapTimeout: \(configuredTapTimeoutMs)ms"
    )

    // If the tap is already running, potentially restart it if master key changed?
    // For now, assumes restart happens externally if needed.

    // Reset sequence state if config changes
    resetSequenceStateInternal()  // Use internal version
  }

  /// Called when the configuration has potentially changed.
  @objc private func masterKeyHeldTimerFired(_ timer: Timer) {
    print("DEBUG: Master key HELD timer fired.")
    masterKeyHeldTimer = nil  // Timer is non-repeating
    if isMasterKeyHeldProcessing {
      print("DEBUG: Master key confirmed HELD.")
      isMasterKeyDown = true  // <-- Update published property
      isMasterKeyHeldProcessing = false
      // Initial sequence state is root (empty path) when hold starts
      // Do NOT reset here, the sequence starts *after* the hold is confirmed
      // resetSequenceStateInternal() // <-- Remove reset here
    } else {
      print(
        "DEBUG: Timer fired, but master key processing was already finished (likely KeyUp occurred)."
      )
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
    keyEvent.post(tap: .cgSessionEventTap)
  }

  private func resetSequenceStateInternal() {
    print("DEBUG: Resetting sequence state. Path cleared.")
    // Only update if the path is not already empty to avoid unnecessary publishes
    if !currentBindingPath.isEmpty {
      currentBindingPath = []  // <-- Update published property
    }
    currentBindingNode = nil  // Reset to root context
  }

  private func keyStringFromEvent(_ event: CGEvent) -> String? {
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    // Use the function that gets string from keyCode only for sequence matching.
    return KeyMapping.getString(for: keyCode)
  }

  // MARK: - Tree Traversal Logic (v2)

  private func processSequenceKey(keyString: String) {
    guard let rootBindings = self.rootBindings, !rootBindings.isEmpty else {
      print("WARN: No bindings loaded or bindings are empty, cannot process sequence key.")
      resetSequenceStateInternal()  // Reset if bindings disappear or are empty
      return
    }

    print(
      "DEBUG: Processing sequence key: \"\(keyString)\". Current path: [\(currentBindingPath.joined(separator: ", "))]"
    )

    var nodeFound = false

    // 1. Check children of current node (AC2.3a)
    if let currentNode = self.currentBindingNode, case .branch(let children) = currentNode {
      if let nextNode = children[keyString] {
        print("DEBUG: Found key '\(keyString)' as child of current node.")
        self.currentBindingPath.append(keyString)
        self.currentBindingNode = nextNode
        nodeFound = true
        checkAndExecuteAction()
        return  // Found and processed
      }
    }

    // 2. If not found in children OR if at root/leaf, check from root and ancestors (AC2.3b)
    if !nodeFound {
      // Check root first
      if let rootNode = rootBindings[keyString] {
        print("DEBUG: Found key '\(keyString)' at root level.")
        self.currentBindingPath = [keyString]  // Start new path from root
        self.currentBindingNode = rootNode
        nodeFound = true
        checkAndExecuteAction()
        return  // Found and processed
      }

      // TODO: Implement ancestor search if needed. The current logic prioritizes
      // restarting from the root if the key isn't a direct child. This might
      // deviate slightly from AC2.3b's strict "traverse up" but often provides
      // a more intuitive user experience (e.g., master->O->A, then press X,
      // triggers root X instead of erroring). If strict ancestor-only lookup
      // is required, this section needs modification.

      /* // Example of strict ancestor search (if desired over root restart):
      for i in stride(from: currentBindingPath.count - 1, through: 0, by: -1) {
          let ancestorPath = Array(currentBindingPath.prefix(i))
          if let ancestorNode = getNode(at: ancestorPath), case .branch(let ancestorChildren) = ancestorNode {
              if let nextNode = ancestorChildren[keyString] {
                   print("DEBUG: Found key '\(keyString)' as child of ancestor at path [\\(ancestorPath.joined(separator: ", "))]")
                   self.currentBindingPath = ancestorPath + [keyString]
                   self.currentBindingNode = nextNode
                   nodeFound = true
                   checkAndExecuteAction()
                   return // Found and processed
              }
          }
          // Also check root level within the loop if current path is not empty
           if i == 0 && currentBindingPath.count > 0 { // Check root only once if not already found
               if let rootNode = rootBindings[keyString] {
                   print("DEBUG: Found key '\(keyString)' at root level (during ancestor check).")
                   self.currentBindingPath = [keyString] // Start new path from root
                   self.currentBindingNode = rootNode
                   nodeFound = true
                   checkAndExecuteAction()
                   return // Found and processed
               }
           }
      }
      */

    }

    // 4. If not found anywhere (AC2.3c)
    if !nodeFound {
      print(
        "DEBUG: Invalid key '\(keyString)' for current sequence path [\\(currentBindingPath.joined(separator: ",
        "))]. No change in state."
      )
      // TODO: Implement user feedback (toast/log) for invalid key (Task 18, AC4.3)
    }
  }

  private func checkAndExecuteAction() {
    guard let node = currentBindingNode else { return }  // Should have a node if we got here

    print(
      "DEBUG: Checking action for node at path: [\(currentBindingPath.joined(separator: ", "))]")

    switch node {
    case .leaf(let action):
      if let action = action {
        print("DEBUG: Found action at leaf node: \(action)")
        if let hyprAction = action.hyprCutAction {
          // Signal completion *before* executing and resetting
          // Pass a copy of the path as it is *right now*
          print("DEBUG: Signaling sequence completion for path: \(currentBindingPath)")
          onSequenceCompleted?(currentBindingPath)

          actionExecutor.execute(action: hyprAction)

          // Reset state immediately now that we've signaled
          revertToParentNode()

        } else {
          print("WARN: Could not convert config Action to executable HyprCutAction.")
          // If action conversion fails, maybe don't signal completion?
          // Or signal and let UI decide? For now, let's just reset.
          revertToParentNode()
        }
      } else {
        // Leaf node with no action defined (AC2.4b)
        print("DEBUG: Found leaf node with no action.")
        // No action, so don't signal completion. Just revert.
        revertToParentNode()
      }
    case .branch:
      // Branch node, do nothing, wait for next key (AC2.4c)
      print("DEBUG: Reached branch node. Waiting for next key.")
      break
    }
  }

  private func revertToParentNode() {
    if !currentBindingPath.isEmpty {
      currentBindingPath.removeLast()
      print("DEBUG: Reverted path to: [\(currentBindingPath.joined(separator: ", "))]")
      // Update currentBindingNode based on the new path
      currentBindingNode = getNode(at: currentBindingPath)
    } else {
      // If path is empty, we are back at the root
      currentBindingNode = nil
      print("DEBUG: Reverted path to root.")
    }
  }

  // Helper to get node at a specific path from root
  private func getNode(at path: [String]) -> BindingNode? {
    guard let bindings = rootBindings else { return nil }
    var currentNode: [String: BindingNode]? = bindings
    var resultNode: BindingNode? = nil  // Conceptually represents the root if path is empty

    for key in path {
      guard let currentDict = currentNode, let nextNode = currentDict[key] else {
        print("WARN: Path [\(path.joined(separator: ", "))] became invalid during traversal.")
        return nil  // Path is invalid
      }
      resultNode = nextNode
      if case .branch(let nodes) = nextNode {
        currentNode = nodes
      } else {
        currentNode = nil  // Reached a leaf, stop descending
      }
    }
    return resultNode
  }

  // Public function to be called by ActionExecutor or other components
  public func resetSequenceState() {  // Make explicitly public
    print("DEBUG: Public resetSequenceState called.")
    resetSequenceStateInternal()
  }

  // MARK: - Configuration Update

  // ... existing code ...
}
