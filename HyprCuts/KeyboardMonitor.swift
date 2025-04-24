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
import os  // Add import

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

  // Logger instance
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "KeyboardMonitor")

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
    logger.info("Starting Keyboard Monitor...")
    setupEventTap()
  }

  func stop() {
    logger.info("Stopping Keyboard Monitor...")
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      if let runLoopSource = runLoopSource {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.runLoopSource = nil  // Release reference
      }
      // CFMachPortInvalidate(eventTap) // This might be needed but test first
      self.eventTap = nil  // Release reference
      logger.info("Event tap disabled and removed from run loop.")
    }
    masterKeyHeldTimer?.invalidate()
    masterKeyHeldTimer = nil
  }

  // MARK: - Event Tap Setup & Handling

  private func setupEventTap() {
    // Check if already running
    guard eventTap == nil else {
      logger.debug("Event tap already configured.")
      return
    }

    // Define the event tap callback closure inline for capturing `self`
    let eventTapCallback: CGEventTapCallBack = {
      proxy, type, event, refcon -> Unmanaged<CGEvent>? in
      // `refcon` holds the `self` reference passed during tap creation.
      // We need to safely unwrap it.
      guard let refcon = refcon else {
        // Use temporary logger as self isn't available
        Logger(subsystem: Bundle.main.bundleIdentifier!, category: "KeyboardMonitor").error(
          "refcon is nil in event tap callback")
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
        // logger.trace("No valid master key configured. Passing event through.") // Use trace/debug if needed
        return Unmanaged.passRetained(event)
      }

      // Use AppKit's NSEvent for easier key code access
      guard let nsEvent = NSEvent(cgEvent: event) else {
        mySelf.logger.error("Error converting CGEvent to NSEvent for key event")
        return Unmanaged.passRetained(event)
      }
      let keyCode = CGKeyCode(nsEvent.keyCode)
      // mySelf.logger.trace("Detected key event - Code: \(keyCode), Type: \(type.rawValue)")

      // Check if it's the configured master key
      if keyCode == targetMasterKeyCode {
        if type == .keyDown {
          // If master key is already confirmed held, or we are already processing a press, ignore repeat keyDowns
          if mySelf.isMasterKeyDown || mySelf.isMasterKeyHeldProcessing {
            // mySelf.logger.trace("Ignoring repeat Master key DOWN event.")
            return nil  // Suppress repeat down events
          }

          // mySelf.logger.trace("Master key DOWN (potential tap/hold)")
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
          mySelf.logger.debug(
            "Starting master key hold timer with timeout: \(timeout, format: .fixed(precision: 3))s"
          )
          mySelf.masterKeyHeldTimer = Timer.scheduledTimer(
            timeInterval: timeout,
            target: mySelf,
            selector: #selector(mySelf.masterKeyHeldTimerFired(_:)),
            userInfo: nil,
            repeats: false
          )

          // mySelf.logger.trace("Suppressing initial Master key DOWN event.")
          return nil  // Suppress the initial down event

        } else {  // .keyUp
          // mySelf.logger.trace("Master key UP received.")
          // Was this the keyUp for our potential tap/hold?
          if mySelf.isMasterKeyHeldProcessing {
            // KeyUp happened *before* the timer fired - it's a TAP
            // mySelf.logger.trace("Detected Master key TAP.")
            mySelf.masterKeyHeldTimer?.invalidate()  // Cancel the timer
            mySelf.masterKeyHeldTimer = nil
            mySelf.isMasterKeyHeldProcessing = false  // Done processing

            // Reset v2 sequence state if tap occurs unexpectedly during processing
            mySelf.resetSequenceStateInternal()

            // Re-post the down/up events for the tap, temporarily disabling our tap
            if let downCode = mySelf.pendingMasterKeyDownCode, let currentTap = mySelf.eventTap {
              let downFlags = mySelf.pendingMasterKeyDownFlags ?? CGEventFlags()  // Use stored flags or default
              let upFlags = event.flags  // Use flags from the actual keyUp event

              // mySelf.logger.trace("Disabling event tap temporarily to replay TAP events.")
              CGEvent.tapEnable(tap: currentTap, enable: false)

              // Synthesize and post events using the helper
              mySelf.postSynthesizedKeyEvent(keyCode: downCode, keyDown: true, flags: downFlags)
              mySelf.postSynthesizedKeyEvent(keyCode: downCode, keyDown: false, flags: upFlags)

              // mySelf.logger.trace("Re-enabling event tap.")
              CGEvent.tapEnable(tap: currentTap, enable: true)

              // Clear stored info
              mySelf.pendingMasterKeyDownCode = nil
              mySelf.pendingMasterKeyDownFlags = nil

              // Reset v2 sequence state if tap occurs unexpectedly during processing
              // This also ensures the published path is cleared
              mySelf.resetSequenceStateInternal()

              // Suppress the original keyUp event in the callback, as we manually synthesized it.
              // mySelf.logger.trace("Suppressing original Master key UP event callback for TAP.")
              return nil
            } else {
              mySelf.logger.warning(
                "Master key TAP detected, but no stored key code or event tap found to replay.")
            }

            // Suppress the original keyUp event in the callback, as we manually synthesized it.
            // mySelf.logger.trace("Suppressing original Master key UP event callback for TAP.")
            return nil
          } else if mySelf.isMasterKeyDown {
            // KeyUp happened *after* the timer fired - it's the end of a HOLD
            // mySelf.logger.trace("Master key HELD released.")
            mySelf.isMasterKeyDown = false  // No longer held <-- Update published state
            mySelf.logger.debug("Master key released (Hold ended). Resetting sequence state.")
            // Clear stored info
            mySelf.pendingMasterKeyDownCode = nil
            mySelf.pendingMasterKeyDownFlags = nil

            // Reset v2 sequence state on master key release
            mySelf.resetSequenceStateInternal()  // <-- This clears the published path

            // We still suppress the original master key up event
            return nil
          } else {
            // Master key was not held or being processed (e.g., keyUp without prior keyDown?). Let it pass.
            // mySelf.logger.trace("Passing through unexpected Master key UP event.")
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
              mySelf.logger.debug("Sequence Key Down: \(keyString)")
              mySelf.processSequenceKey(keyString: keyString)
            } else {
              mySelf.logger.warning("Could not get string representation for key code \(keyCode)")
              // Optionally provide feedback for unrecognized keys
            }
          }
          // Suppress other keys (down and up) while master key is held
          // mySelf.logger.trace("Suppressing sequence key event (Code: \(keyCode), Type: \(type.rawValue))")
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
      logger.critical("Failed to create event tap. Check Accessibility Permissions.")
      // TODO: Handle this error robustly (Task 4, 12, 28) - Maybe via delegate/notification
      // Consider showing an alert or updating the menu bar icon via AppDelegate.
      return
    }
    logger.info("Event tap created successfully.")

    // Create a run loop source and add it to the current run loop.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    guard let runLoopSource = runLoopSource else {
      logger.critical("Failed to create run loop source.")
      CFMachPortInvalidate(eventTap)  // Clean up the tap
      self.eventTap = nil
      // TODO: Handle this error robustly - Maybe via delegate/notification
      return
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    logger.debug("Event tap added to run loop.")

    // Enable the event tap.
    CGEvent.tapEnable(tap: eventTap, enable: true)
    logger.info("Event tap enabled.")
  }

  // MARK: - Configuration Handling

  /// Updates the monitor's behavior based on the current ConfigManager state.
  func updateConfigValues() {
    logger.info("Updating config values...")
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
      logger.warning("Master key not found in config.")
    }
    self.configuredTapTimeoutMs = configManager.getMasterKeyTapTimeout()

    // Load the v2 bindings tree
    self.rootBindings = configManager.getBindings()
    if self.rootBindings == nil || self.rootBindings!.isEmpty {
      logger.warning("No bindings loaded or bindings are empty.")
    }

    logger.info(
      "Config updated. MasterKeyCode: \(String(describing: self.configuredMasterKeyCode)), TapTimeout: \(self.configuredTapTimeoutMs)ms"
    )

    // If the tap is already running, potentially restart it if master key changed?
    // For now, assumes restart happens externally if needed.

    // Reset sequence state if config changes
    resetSequenceStateInternal()  // Use internal version
  }

  /// Called when the configuration has potentially changed.
  @objc private func masterKeyHeldTimerFired(_ timer: Timer) {
    logger.debug("Master key HELD timer fired.")
    masterKeyHeldTimer = nil  // Timer is non-repeating
    if isMasterKeyHeldProcessing {
      logger.debug("Master key confirmed HELD.")
      isMasterKeyDown = true  // <-- Update published property
      isMasterKeyHeldProcessing = false
      // Initial sequence state is root (empty path) when hold starts
      // Do NOT reset here, the sequence starts *after* the hold is confirmed
      // resetSequenceStateInternal() // <-- Remove reset here
    } else {
      logger.debug(
        "Timer fired, but master key processing was already finished (likely KeyUp occurred).")
    }
  }

  // MARK: - Helpers

  // Helper function to synthesize and post key events
  private func postSynthesizedKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      logger.error("Failed to create event source for synthesizing key event.")
      return
    }
    guard let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
    else {
      logger.error("Failed to create keyboard event for synthesizing.")
      return
    }
    keyEvent.flags = flags
    keyEvent.post(tap: .cgSessionEventTap)
  }

  private func resetSequenceStateInternal() {
    logger.debug("Resetting sequence state. Path cleared.")
    // Only update if the path is not already empty to avoid unnecessary publishes
    if !self.currentBindingPath.isEmpty {
      self.currentBindingPath = []  // <-- Update published property
    }
    self.currentBindingNode = nil  // Reset to root context
  }

  private func keyStringFromEvent(_ event: CGEvent) -> String? {
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    // Use the function that gets string from keyCode only for sequence matching.
    return KeyMapping.getString(for: keyCode)
  }

  // MARK: - Tree Traversal Logic (v2)

  private func processSequenceKey(keyString: String) {
    guard let rootBindings = self.rootBindings, !rootBindings.isEmpty else {
      logger.warning("No bindings loaded or bindings are empty, cannot process sequence key.")
      self.resetSequenceStateInternal()  // Reset if bindings disappear or are empty
      return
    }

    logger.debug(
      "Processing sequence key: \"\(keyString)\". Current path: [\(self.currentBindingPath.joined(separator: ", "))]"
    )

    var nodeFound = false

    // 1. Check children of current node (AC2.3a)
    if let currentNode = self.currentBindingNode, case .branch(let children) = currentNode {
      if let nextNode = children[keyString] {
        logger.debug("Found key '\(keyString)' as child of current node.")
        self.currentBindingPath.append(keyString)
        self.currentBindingNode = nextNode
        nodeFound = true
        self.checkAndExecuteAction()
        return  // Found and processed
      }
    }

    // 2. If not found in children OR if at root/leaf, check from root and ancestors (AC2.3b)
    if !nodeFound {
      // Check root first
      if let rootNode = self.rootBindings?[keyString] {
        logger.debug("Found key '\(keyString)' at root level.")
        self.currentBindingPath = [keyString]  // Start new path from root
        self.currentBindingNode = rootNode
        nodeFound = true
        self.checkAndExecuteAction()
        return  // Found and processed
      }

      // TODO: Implement ancestor search if needed. The current logic prioritizes
      // restarting from the root if the key isn't a direct child. This might
      // deviate slightly from AC2.3b's strict "traverse up" but often provides
      // a more intuitive user experience (e.g., master->O->A, then press X,
      // triggers root X instead of erroring). If strict ancestor-only lookup
      // is required, this section needs modification.

      /* // Example of strict ancestor search (if desired over root restart):
      for i in stride(from: self.currentBindingPath.count - 1, through: 0, by: -1) {
          let ancestorPath = Array(self.currentBindingPath.prefix(i))
          if let ancestorNode = self.getNode(at: ancestorPath), case .branch(let ancestorChildren) = ancestorNode {
              if let nextNode = ancestorChildren[keyString] {
                   logger.trace("Found key '\(keyString)' as child of ancestor at path [\(ancestorPath.joined(separator: ", "))]")
                   self.currentBindingPath = ancestorPath + [keyString]
                   self.currentBindingNode = nextNode
                   nodeFound = true
                   self.checkAndExecuteAction()
                   return // Found and processed
              }
          }
          // Also check root level within the loop if current path is not empty
           if i == 0 && self.currentBindingPath.count > 0 { // Check root only once if not already found
               if let rootNode = self.rootBindings[keyString] {
                   logger.trace("Found key '\(keyString)' at root level (during ancestor check).")
                   self.currentBindingPath = [keyString] // Start new path from root
                   self.currentBindingNode = rootNode
                   nodeFound = true
                   self.checkAndExecuteAction()
                   return // Found and processed
               }
           }
      }
      */

    }

    // 4. If not found anywhere (AC2.3c)
    if !nodeFound {
      logger.debug(
        "Invalid key '\(keyString)' for current sequence path [\(self.currentBindingPath.joined(separator: ", "))]. No change in state."
      )
      // TODO: Implement user feedback (toast/log) for invalid key (Task 18, AC4.3)
    }
  }

  private func checkAndExecuteAction() {
    guard let node = self.currentBindingNode else { return }
    guard let lastKey = self.currentBindingPath.last else {
      logger.warning("checkAndExecuteAction called with empty path. Cannot determine slot key.")
      self.resetSequenceStateInternal()
      return
    }

    logger.debug(
      "Checking action for node at path: [\(self.currentBindingPath.joined(separator: ", "))]"
    )

    switch node {
    case .leaf(let configAction):
      if let configAction = configAction {
        // Action leaf
        logger.debug("Found action at leaf node: \(configAction)")
        var actionToExecute: HyprCutAction? = nil

        // Determine the action, handling Harpoon specifically
        switch configAction {
        case .harpoonSet:
          actionToExecute = .harpoonSet(slotKey: lastKey)
        case .harpoonRm:
          actionToExecute = .harpoonRm(slotKey: lastKey)
        case .harpoonGo:
          actionToExecute = .harpoonGo(slotKey: lastKey)
        case .harpoonReset:
          actionToExecute = HyprCutAction.harpoonReset
        default:
          actionToExecute = configAction.hyprCutAction  // Use converter for others
        }

        // Execute if an action was determined
        if let finalAction = actionToExecute {
          self.executeAndRevert(action: finalAction)
        } else {
          // Log if converter failed for a non-Harpoon action
          switch configAction {
          case .harpoonSet, .harpoonRm, .harpoonGo, .harpoonReset:
            // Don't log warning if a harpoon action couldn't be converted (shouldn't happen)
            break
          default:
            // Log warning only for non-harpoon actions that failed conversion
            logger.warning(
              "Could not convert config Action to executable HyprCutAction: \(configAction)")
          }
          // Revert even if action is nil or fails conversion
          self.revertToParentNode()
        }

      } else {
        // Leaf node with no action defined (AC2.4b)
        logger.debug("Found leaf node with no action.")
        self.revertToParentNode()
      }

    case .branch:
      // Branch node, do nothing, wait for next key (AC2.4c)
      logger.debug("Reached branch node. Waiting for next key.")
      // No state change needed here, just wait for the next key event
      break
    }
  }

  // Helper function to execute action and revert state
  private func executeAndRevert(action: HyprCutAction) {
    logger.debug("Signaling sequence completion for path: \(self.currentBindingPath)")
    self.onSequenceCompleted?(self.currentBindingPath)

    logger.debug("Executing action: \(action)")
    self.actionExecutor.execute(action: action)

    // Reset state immediately after executing
    self.revertToParentNode()
  }

  private func revertToParentNode() {
    if !self.currentBindingPath.isEmpty {
      self.currentBindingPath.removeLast()
      logger.debug("Reverted path to: [\(self.currentBindingPath.joined(separator: ", "))]")
      // Update currentBindingNode based on the new path
      self.currentBindingNode = self.getNode(at: self.currentBindingPath)
    } else {
      // If path is empty, we are back at the root
      self.currentBindingNode = nil
      logger.debug("Reverted path to root.")
    }
  }

  // Helper to get node at a specific path from root
  private func getNode(at path: [String]) -> BindingNode? {
    guard let bindings = self.rootBindings else { return nil }
    var currentNode: [String: BindingNode]? = bindings
    var resultNode: BindingNode? = nil  // Conceptually represents the root if path is empty

    for key in path {
      guard let currentDict = currentNode, let nextNode = currentDict[key] else {
        logger.warning("Path [\(path.joined(separator: ", "))] became invalid during traversal.")
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
    logger.debug("Public resetSequenceState called.")
    self.resetSequenceStateInternal()
  }

  // MARK: - Configuration Update

  // ... existing code ...
}
