//
//  ActionExecutor.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import AppKit  // Needed for NSEvent
import Foundation

// Updated enum to match config action types
enum HyprCutAction {
  case openApp(target: String)
  case runShellCommand(command: String)
  case typeKeys(keysString: String)  // Using comma-separated string for now
  case debugPrintKeyEvent(event: NSEvent)  // Keeping debug action
}

class ActionExecutor {

  func execute(action: HyprCutAction) {
    switch action {
    case .openApp(let target):
      handleOpenApp(target: target)
    case .runShellCommand(let command):
      handleRunShellCommand(command: command)
    case .typeKeys(let keysString):
      handleTypeKeys(keysString: keysString)
    case .debugPrintKeyEvent(let event):
      handleDebugPrintKeyEvent(event: event)
    }
  }

  // MARK: - Mock Action Handlers

  private func handleOpenApp(target: String) {
    print("ActionExecutor [Mock]: Executing openApp with target='\(target)'")
    // Actual implementation will involve NSWorkspace
  }

  private func handleRunShellCommand(command: String) {
    print("ActionExecutor [Mock]: Executing shellCommand with command='\(command)'")
    // Actual implementation will involve Process
  }

  private func handleTypeKeys(keysString: String) {
    // We'll need to parse the keysString back into an array later
    print("ActionExecutor [Mock]: Executing typeKeys with keys='\(keysString)'")
    // Actual implementation will involve CGEvent posting
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
