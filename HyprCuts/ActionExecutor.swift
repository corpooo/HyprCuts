//
//  ActionExecutor.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import AppKit  // Needed for NSEvent
import Foundation

// Defines the different types of actions HyprCuts can perform.
// TODO: Expand with actual actions from AC4.1 (open_app, shell_command, keys)
enum HyprCutAction {
  // A debug action to print details of the key event that triggered it.
  case debugPrintKeyEvent(event: NSEvent)
  // Add other action types here later, e.g.:
  // case openApp(target: String)
  // case runShellCommand(command: String)
  // case typeKeys(keys: [String])
}

class ActionExecutor {

  // Executes the specified HyprCutAction.
  func execute(action: HyprCutAction) {
    switch action {
    case .debugPrintKeyEvent(let event):
      handleDebugPrintKeyEvent(event: event)
    // Add cases for other actions here later
    // case .openApp(let target):
    //   print("Executing openApp: \(target)") // Placeholder
    // case .runShellCommand(let command):
    //   print("Executing shellCommand: \(command)") // Placeholder
    // case .typeKeys(let keys):
    //   print("Executing typeKeys: \(keys)") // Placeholder
    }
  }

  // MARK: - Action Handlers

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
