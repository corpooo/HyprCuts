//
//  SequenceNotificationController.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 23.04.2025.
//

import AppKit  // Needed for NSWindow, NSScreen, NSHostingController, NSHostingView
import Combine
import Foundation
import SwiftUI

// MARK: - Notification Window Controller
class SequenceNotificationController {
  private var notificationWindow: NSWindow?
  private var keyboardMonitor: KeyboardMonitor
  private var configManager = ConfigManager.shared
  private var cancellables = Set<AnyCancellable>()

  // Timer for keeping the last sequence visible
  private var persistentDisplayTimer: Timer?
  // Make this duration longer for persistent display
  private let persistentDisplayDuration: TimeInterval = 3.0

  // Store the last path that was actually shown (especially the completed one)
  private var lastDisplayedPath: [String] = []

  // Store the master key string representation
  private var masterKeyDisplayString: String = "?"

  // Keep track of the master key state to detect changes
  private var wasMasterKeyDown: Bool = false
  private var isDisplayLocked: Bool = false  // Flag to lock display on last completed sequence

  init(keyboardMonitor: KeyboardMonitor) {
    self.keyboardMonitor = keyboardMonitor
    print("SequenceNotificationController Initialized")
    self.wasMasterKeyDown = keyboardMonitor.isMasterKeyDown
    updateMasterKeyDisplay()
    setupBindings()
    setupCallbacks()  // Call new setup method

    // Listen for config changes to update master key display string and visibility
    NotificationCenter.default.publisher(for: ConfigManager.configReloadedNotification)
      .receive(on: RunLoop.main)  // Ensure UI updates on main thread
      .sink { [weak self] _ in
        print(
          "DEBUG: Config reloaded notification received by SequenceNotificationController."
        )
        self?.updateMasterKeyDisplay()
        // Re-evaluate visibility based on potentially changed show_sequence_notification
        self?.updateNotificationVisibility()
      }
      .store(in: &cancellables)
  }

  private func updateMasterKeyDisplay() {
    masterKeyDisplayString = configManager.getMasterKeyDisplayString() ?? "?"
    print("DEBUG: Updated master key display string to: \(masterKeyDisplayString)")
    // If window exists, update its view
    if let window = notificationWindow,
      let hostingView = window.contentView as? NSHostingView<SequenceNotificationView>
    {
      print("DEBUG: Updating existing notification view with new master key string.")
      hostingView.rootView = SequenceNotificationView(
        sequencePath: keyboardMonitor.currentBindingPath,
        masterKeyString: masterKeyDisplayString)
      // Maybe re-pack needed if master key string length changes significantly?
      // window.pack()
    }
  }

  // New method to set up callbacks from the monitor
  private func setupCallbacks() {
    keyboardMonitor.onSequenceCompleted = { [weak self] completedPath in
      // This is called explicitly when a sequence leads to an action
      print("DEBUG: onSequenceCompleted callback received with path: \(completedPath)")
      self?.handleSequenceCompletion(path: completedPath)
    }
  }

  // Handles the logic when a sequence is confirmed completed
  private func handleSequenceCompletion(path: [String]) {
    guard configManager.showSequenceNotification else { return }  // Check setting

    print("DEBUG: Locking display for persistent view of path: \(path)")
    isDisplayLocked = true  // Lock the display to this path
    lastDisplayedPath = path  // Store the path to display

    // Ensure the notification shows this completed path
    showOrUpdateNotification(path: path)

    // Cancel any previous timer and start the persistent display timer
    persistentDisplayTimer?.invalidate()
    print("DEBUG: Starting persistent display timer after sequence completion.")
    persistentDisplayTimer = Timer.scheduledTimer(
      timeInterval: persistentDisplayDuration,
      target: self,
      selector: #selector(persistentDisplayTimerFired),
      userInfo: nil,
      repeats: false
    )
    RunLoop.main.add(persistentDisplayTimer!, forMode: .common)
  }

  private func setupBindings() {
    print("Setting up bindings for SequenceNotificationController")

    // Listener mostly for master key state changes and intermediate path display
    keyboardMonitor.$isMasterKeyDown
      .combineLatest(keyboardMonitor.$currentBindingPath, configManager.$showSequenceNotification)
      .receive(on: RunLoop.main)
      .sink { [weak self] isDown, path, showNotificationSetting in
        guard let self = self else { return }

        let masterKeyJustPressed = isDown && !self.wasMasterKeyDown
        let masterKeyJustReleased = !isDown && self.wasMasterKeyDown

        // --- Handle Sequence Start (Master Key Down) ---
        if masterKeyJustPressed {
          print("DEBUG: Master key pressed - resetting UI state.")
          // Unlock display, cancel timer, hide window
          self.isDisplayLocked = false
          self.persistentDisplayTimer?.invalidate()
          self.persistentDisplayTimer = nil
          self.hideNotification()  // Hide immediately

          // Clear the stored path
          self.lastDisplayedPath = []

          // Show initial notification if setting allows
          if showNotificationSetting {
            self.showOrUpdateNotification(path: [])  // Show master key only
          }
          // Update tracking state *before* returning
          self.wasMasterKeyDown = isDown
          return  // Exit sink early, state is reset
        }

        // If display is locked, ignore intermediate path updates and release events
        if self.isDisplayLocked {
          print("DEBUG: Display is locked, ignoring sink update.")
          // Update tracking state *before* returning
          self.wasMasterKeyDown = isDown
          return
        }

        // --- Handle Sequence Progression (Key Pressed while Master Held, display not locked) ---
        if isDown && !path.isEmpty && showNotificationSetting {
          print("DEBUG: Sequence progressing (UI update) - path: \(path)")
          self.showOrUpdateNotification(path: path)  // Show intermediate path
          // Update lastDisplayedPath continuously during progression
          self.lastDisplayedPath = path
        }
        // --- Handle Master Key Release (display not locked) ---
        else if masterKeyJustReleased {
          print("DEBUG: Master key released (display not locked).")
          // Hide immediately if master key is released without sequence completion lock
          self.hideNotification()
        }
        // --- Handle Path Becoming Empty (display not locked, e.g., invalid key) ---
        else if isDown && path.isEmpty && self.wasMasterKeyDown {
          print("DEBUG: Path reset internally (display not locked). Hiding.")
          self.hideNotification()
        }

        // Update tracking state for next event
        self.wasMasterKeyDown = isDown
      }
      .store(in: &cancellables)
  }

  // Call this explicitly when config reloads to check the showNotificationSetting
  func updateNotificationVisibility() {
    if !configManager.showSequenceNotification {
      print("DEBUG: Hiding notification due to config change (showSequenceNotification = false).")
      persistentDisplayTimer?.invalidate()
      persistentDisplayTimer = nil
      hideNotification()
    } else {
      // If setting is true, the regular sink logic will handle showing/hiding.
      // We could potentially re-show the last state if it was hidden due to config,
      // but let's keep it simple for now.
      print(
        "DEBUG: Config reloaded (showSequenceNotification = true), visibility managed by state bindings."
      )
    }
  }

  private func showOrUpdateNotification(path: [String]) {
    // print("DEBUG: showOrUpdateNotification called with path: \(path)")
    if notificationWindow == nil {
      createNotificationWindow()
    }

    guard let window = notificationWindow,
      let screen = NSScreen.main
    else {  // Position based on main screen
      print("ERROR: Notification window or main screen not available.")
      return
    }

    // --- Update View Content --- (Ensure this runs on main thread - handled by .receive(on:))
    let newView = SequenceNotificationView(
      sequencePath: path, masterKeyString: self.masterKeyDisplayString)
    if let hostingView = window.contentView as? NSHostingView<SequenceNotificationView> {
      // Only update if the path or master key has actually changed
      if hostingView.rootView.sequencePath != path
        || hostingView.rootView.masterKeyString != self.masterKeyDisplayString
      {
        print("DEBUG: Updating notification view content.")
        hostingView.rootView = newView
        window.setContentSize(hostingView.fittingSize)  // Resize window to fit SwiftUI content
      } else {
        // print("DEBUG: Notification view content is already up-to-date.")
      }
    } else {
      print("ERROR: Could not get hosting view to update content.")
      return  // Exit if we can't update
    }

    // --- Positioning --- (Ensure this runs on main thread)
    let windowSize = window.frame.size  // Use the updated size
    let screenRect = screen.visibleFrame  // Use visibleFrame to avoid menu bar/dock
    // Center horizontally, position near bottom vertically
    let xPos = screenRect.origin.x + (screenRect.width - windowSize.width) / 2
    let yPos = screenRect.origin.y + 60  // Slightly higher offset from bottom

    // Only set frame if it needs changing (avoids unnecessary redraws)
    if window.frame.origin != NSPoint(x: xPos, y: yPos) {
      // print("DEBUG: Setting notification window origin to: (\(xPos), \(yPos))")
      window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
    }

    // Ensure window is visible and ordered front
    if !window.isVisible {
      print("DEBUG: Making notification window visible.")
      // window.orderFrontRegardless() // Make it visible without activating app
      window.orderFrontRegardless()  // Use this to show window without activating app
    }
  }

  @objc private func persistentDisplayTimerFired() {
    print("DEBUG: Persistent display timer fired.")
    // Unlock display before hiding
    isDisplayLocked = false
    hideNotification()
  }

  // This function now only performs the actual hiding
  private func hideNotification() {
    // print("DEBUG: hideNotification called.")
    persistentDisplayTimer?.invalidate()  // Ensure timer is stopped
    persistentDisplayTimer = nil
    isDisplayLocked = false  // Ensure display is unlocked when hiding

    DispatchQueue.main.async {
      // Hide window
      if let window = self.notificationWindow, window.isVisible {
        print("DEBUG: Hiding notification window.")
        window.orderOut(nil)
      }
    }
  }

  private func createNotificationWindow() {
    print("DEBUG: Creating notification window.")
    // Ensure window creation happens on the main thread
    DispatchQueue.main.async { [weak self] in  // Use weak self to avoid potential retain cycles if needed
      guard let self = self else { return }

      // Initial view with empty path, using the current master key string
      let initialView = SequenceNotificationView(
        sequencePath: [], masterKeyString: self.masterKeyDisplayString)

      // Use NSHostingController to embed SwiftUI view
      let hostingController = NSHostingController(rootView: initialView)
      let window = NSWindow(contentViewController: hostingController)

      window.isReleasedWhenClosed = false  // Keep window instance around
      window.level = .floating  // Keep it above most other windows
      window.styleMask = [.borderless]  // No title bar or border
      window.backgroundColor = .clear  // Transparent background
      window.isOpaque = false  // Allows transparency
      window.hasShadow = false  // We add shadow in SwiftUI view if needed
      window.ignoresMouseEvents = true  // Pass clicks through
      window.isMovableByWindowBackground = false  // Not draggable
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]  // Visible on all spaces, ignore cycle

      self.notificationWindow = window
      print("DEBUG: Notification window created successfully.")
      // Initial size and position will be set in showOrUpdateNotification
    }
  }

  deinit {
    print("SequenceNotificationController Deinitialized")
    cancellables.forEach { $0.cancel() }
    persistentDisplayTimer?.invalidate()
    DispatchQueue.main.async {
      self.notificationWindow?.close()
    }
  }
}
