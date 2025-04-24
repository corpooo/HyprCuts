//
//  ActionExecutor.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import AppKit  // Needed for NSEvent
import Foundation
import os  // Import os for logging

// Make enum internal (default access level) so it's accessible from ConfigManager
enum HyprCutAction: CustomStringConvertible {
  case openApp(target: String)
  case runShellCommand(command: String)
  case typeKeys(keys: [String])
  case debugPrintKeyEvent(event: NSEvent)  // Keeping debug action
  case resetSequenceState  // Added for v2 reset action (Task 25)

  // Harpoon Actions (Task 35+)
  case harpoonSet(slotKey: String)
  case harpoonRm(slotKey: String)
  case harpoonGo(slotKey: String)
  case harpoonReset

  // FIX: Implement CustomStringConvertible
  var description: String {
    switch self {
    case .openApp(let target):
      return "openApp(target: \(target))"
    case .runShellCommand(let command):
      // Truncate command for safety/brevity in logs
      let truncatedCommand = command.count > 50 ? String(command.prefix(47)) + "..." : command
      return "runShellCommand(command: \(truncatedCommand))"
    case .typeKeys(let keys):
      return "typeKeys(keys: [\(keys.joined(separator: ", "))])"
    case .debugPrintKeyEvent(let event):
      // Provide a minimal description for the debug event
      return "debugPrintKeyEvent(keyCode: \(event.keyCode))"
    case .resetSequenceState:
      return "resetSequenceState"
    case .harpoonSet(let slotKey):
      return "harpoonSet(slotKey: \(slotKey))"
    case .harpoonRm(let slotKey):
      return "harpoonRm(slotKey: \(slotKey))"
    case .harpoonGo(let slotKey):
      return "harpoonGo(slotKey: \(slotKey))"
    case .harpoonReset:
      return "harpoonReset"
    }
  }
}

class ActionExecutor {
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ActionExecutor")

  func execute(action: HyprCutAction) {
    switch action {
    case .openApp(let target):
      handleOpenApp(target: target)
    case .runShellCommand(let command):
      handleRunShellCommand(command: command)
    case .typeKeys(let keys):
      handleTypeKeys(keys: keys)
    case .debugPrintKeyEvent(let event):
      handleDebugPrintKeyEvent(event: event)
    case .resetSequenceState:
      handleResetSequenceState()  // Call new handler
    case .harpoonSet(let slotKey):
      handleHarpoonSet(slotKey: slotKey)
    case .harpoonRm(let slotKey):
      handleHarpoonRm(slotKey: slotKey)
    case .harpoonGo(let slotKey):
      handleHarpoonGo(slotKey: slotKey)
    case .harpoonReset:
      handleHarpoonReset()
    }
  }

  // MARK: - Mock Action Handlers

  private func handleOpenApp(target: String) {
    // print("ActionExecutor [Mock]: Executing openApp with target='\(target)'")
    // Actual implementation will involve NSWorkspace
    let workspace = NSWorkspace.shared
    var appURL: URL?

    // Try interpreting the target as a full path first
    if target.hasPrefix("/") && FileManager.default.fileExists(atPath: target) {
      appURL = URL(fileURLWithPath: target)
    }
    // Try finding by bundle identifier
    else if target.contains(".") {  // Basic check for bundle ID format
      appURL = workspace.urlForApplication(withBundleIdentifier: target)
    }

    // If not found by bundle ID or path, try searching standard Application folders by name
    if appURL == nil {
      let fileManager = FileManager.default
      let appFolders = [
        "/Applications",
        (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
          .path,
      ]

      let appNameWithExtension = target.hasSuffix(".app") ? target : target + ".app"

      for folderPath in appFolders {
        let potentialPath = (folderPath as NSString).appendingPathComponent(appNameWithExtension)
        if fileManager.fileExists(atPath: potentialPath) {
          appURL = URL(fileURLWithPath: potentialPath)
          print("ActionExecutor: Found '\(appNameWithExtension)' in '\(folderPath)'")
          break  // Found it, stop searching
        }
      }
    }
    // Removed deprecated name lookup using fullPath(forApplication:)
    // Lookup now requires full path or bundle identifier.
    // if appURL == nil {
    //     if let path = workspace.fullPath(forApplication: target) {
    //          appURL = URL(fileURLWithPath: path)
    //     }
    // }

    guard let finalURL = appURL else {
      print(
        "ActionExecutor [Error]: Could not find application specified by target '\(target)'. Please use a full path or bundle identifier."
      )  // Updated error message
      // TODO: Implement user-facing error notification (Task 24, 27c)
      return
    }

    // Launch the application. `.prominent` brings it to the front.
    // Add `.newInstance` if you always want a new instance (less common).
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true  // Equivalent to prominent
    // configuration.addsToRecentItems = false // Optional: prevent adding to Recents

    workspace.openApplication(at: finalURL, configuration: configuration) {
      runningApplication, error in
      if let error = error {
        print(
          "ActionExecutor [Error]: Failed to launch or activate application '\(target)': \(error.localizedDescription)"
        )
        // TODO: Implement user-facing error notification (Task 24, 27c)
      } else {
        print("ActionExecutor: Successfully launched or activated application '\(target)'")
      }
    }
  }

  private func handleRunShellCommand(command: String) {
    // print("ActionExecutor [Mock]: Executing shellCommand with command='\(command)'")
    // Actual implementation will involve Process
    print("ActionExecutor: Executing shell command '\(command)'")

    let task = Process()
    // Use zsh, common default shell. Could use /bin/sh for wider compatibility if needed.
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]  // -c tells the shell to execute the command string

    // Optional: Capture output/error streams if needed later
    // let outputPipe = Pipe()
    // let errorPipe = Pipe()
    // task.standardOutput = outputPipe
    // task.standardError = errorPipe

    do {
      try task.run()  // Executes synchronously
      task.waitUntilExit()  // Wait for the process to finish

      // Check termination status
      if task.terminationStatus == 0 {
        print("ActionExecutor: Shell command completed successfully.")
        // Read output if captured:
        // let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        // if let outputString = String(data: outputData, encoding: .utf8), !outputString.isEmpty {
        //     print("Shell Output: \(outputString)")
        // }
      } else {
        print("ActionExecutor [Error]: Shell command failed with status \(task.terminationStatus).")
        // Read error output if captured:
        // let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        // if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
        //     print("Shell Error Output: \(errorString)")
        // }
        // TODO: Implement user-facing error notification (Task 24, 27c)
      }
    } catch {
      print(
        "ActionExecutor [Error]: Failed to run shell command '\(command)'. Error: \(error.localizedDescription)"
      )
      // TODO: Implement user-facing error notification (Task 24, 27c)
    }
  }

  private func handleTypeKeys(keys: [String]) {
    // Print the strings directly for the mock
    let keysDescription = keys.joined(separator: ", ")  // Simpler join for strings
    print("ActionExecutor [Mock]: Executing typeKeys with keys=[\(keysDescription)]")
    // Actual implementation will involve CGEvent posting and parsing these strings
  }

  // MARK: - New v2 Action Handler

  private func handleResetSequenceState() {
    // This function will likely need to interact with KeyboardMonitor
    // to tell it to reset its internal sequence state.
    // For now, just print a message.
    print("ActionExecutor: Executing resetSequenceState action.")
    // TODO: Implement interaction with KeyboardMonitor to reset its state (Task 1b, 25)
  }

  // MARK: - Harpoon Action Handlers

  private func handleHarpoonSet(slotKey: String) {
    logger.debug("Executing harpoon:set for slot '\(slotKey)'")
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
      // Task 40b: Error notification
      logger.error("Harpoon Error: Could not determine frontmost application.")
      return
    }

    guard let bundleIdentifier = frontmostApp.bundleIdentifier else {
      let appName = frontmostApp.localizedName ?? "Unknown"
      // Task 40b: Error notification
      logger.error("Harpoon Error: Could not get bundle identifier for '\(appName)'.")
      return
    }

    let appName = frontmostApp.localizedName ?? bundleIdentifier  // Prefer name for logging
    HarpoonManager.shared.setPairing(forKey: slotKey, bundleIdentifier: bundleIdentifier)
    // Task 40a: Confirmation notification
    logger.info("Harpoon: Set slot '\(slotKey)' to '\(appName)'.")
  }

  private func handleHarpoonRm(slotKey: String) {
    logger.debug("Executing harpoon:rm for slot '\(slotKey)'")
    if HarpoonManager.shared.getPairing(forKey: slotKey) != nil {
      HarpoonManager.shared.removePairing(forKey: slotKey)
      // Task 40a: Confirmation notification
      logger.info("Harpoon: Removed pairing for slot '\(slotKey)'.")
    } else {
      // Task 40a: Feedback for non-existent pairing
      logger.warning("Harpoon: No pairing found for slot '\(slotKey)'.")
    }
  }

  private func handleHarpoonGo(slotKey: String) {
    logger.debug("Executing harpoon:go for slot '\(slotKey)'")
    guard let bundleIdentifier = HarpoonManager.shared.getPairing(forKey: slotKey) else {
      // Task 40a: Feedback for non-existent pairing
      logger.warning("Harpoon: No pairing found for slot '\(slotKey)'.")
      return
    }

    logger.info("Harpoon: Attempting to activate slot '\(slotKey)' ('\(bundleIdentifier)').")

    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    else {
      // Task 40b: Error notification (could potentially happen if app was uninstalled)
      logger.error(
        "Harpoon Error: Could not find application URL for bundle identifier '\(bundleIdentifier)' (paired with slot '\(slotKey)')."
      )
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true  // Equivalent to activating/bringing to front

    NSWorkspace.shared.open(appURL, configuration: configuration) {
      runningApp, error in
      if let error = error {
        let appName = runningApp?.localizedName ?? bundleIdentifier
        // Task 40b: Error notification
        self.logger.error(
          "Harpoon Error: Failed to activate '\(appName)' for slot '\(slotKey)': \(error.localizedDescription)"
        )
      } else if let app = runningApp {
        // No success notification needed per AC, app appearing is feedback
        self.logger.info(
          "Harpoon: Successfully activated '\(app.localizedName ?? bundleIdentifier)' for slot '\(slotKey)'."
        )
      } else {
        // Task 40b: Error notification
        self.logger.error(
          "Harpoon Error: Unknown error activating application for slot '\(slotKey)' ('\(bundleIdentifier)')."
        )
      }
    }
  }

  private func handleHarpoonReset() {
    logger.debug("Executing harpoon:reset")
    HarpoonManager.shared.clearAllPairings()
    // Task 40a: Confirmation notification
    logger.info("Harpoon: All pairings reset.")
  }

  // MARK: - Existing Debug Handler (No changes needed below)

  private func handleDebugPrintKeyEvent(event: NSEvent) {
    let keyCode = CGKeyCode(event.keyCode)
    let eventFlags = event.modifierFlags  // Use NSEvent's modifierFlags

    // Use NSEvent's characters property, which correctly handles modifiers like Shift.
    if let chars = event.characters {
      if !chars.isEmpty {
        print(
          "ActionExecutor [Debug]: Character='" + chars + "' (Code: " + String(keyCode)
            + ", NSEvent Flags: " + String(eventFlags.rawValue) + ")")
      } else {
        // Handle keys that don't produce standard characters (e.g., function keys, arrows)
        // We might still get key code info here.
        print(
          "ActionExecutor [Debug]: Non-character key (Code: " + String(keyCode)
            + ", NSEvent Flags: " + String(eventFlags.rawValue) + ")")
      }
    } else {
      // Fallback if characters property is nil for some reason
      print(
        "ActionExecutor [Debug]: Could not get character (Code: " + String(keyCode)
          + ", NSEvent Flags: " + String(eventFlags.rawValue) + ")")
    }
  }

  // Add private handler functions for other actions here
}
