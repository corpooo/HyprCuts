//
//  ConfigManager.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import CoreGraphics  // Import for CGKeyCode and CGEventFlags
import Foundation
import Yams  // Make sure Yams is added via SPM

// NOTE: Add 'Yams' dependency via SPM: https://github.com/jpsim/Yams.git
// import Yams

// MARK: - Configuration Data Structures (Task 10)

struct AppConfig: Decodable {
  let masterKey: String
  let masterKeyTapTimeoutMs: Int?  // Use this for tap/hold differentiation, optional
  let showSequenceNotification: Bool
  var bindings: [Binding]

  enum CodingKeys: String, CodingKey {
    case masterKey = "master_key"
    case masterKeyTapTimeoutMs = "master_key_tap_timeout_ms"  // Add the correct key
    case showSequenceNotification = "show_sequence_notification"
    case bindings
  }
}

struct Binding: Decodable {
  let keys: [String]
  let action: Action
  let description: String?  // Optional description

  // Custom initializer to handle decoding and ignore parsedKeys
  enum CodingKeys: String, CodingKey {
    case keys, action, description
    // We omit parsedKeys here as it's not in the YAML
  }
}

enum Action: Decodable {
  case openApp(target: String)
  case shellCommand(command: String)
  case keys(keys: [String])

  // Custom Decodable implementation for action types
  private enum CodingKeys: String, CodingKey {
    case type, target, command, keys
  }

  // Computed property to convert Action -> HyprCutAction
  var hyprCutAction: HyprCutAction? {
    switch self {
    case .openApp(let target):
      return .openApp(target: target)
    case .shellCommand(let command):
      return .runShellCommand(command: command)  // Ensure case name matches HyprCutAction
    case .keys(let keys):
      return .typeKeys(keys: keys)  // Pass [String] directly
    // No default needed as all Action cases are covered
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "open_app":
      let target = try container.decode(String.self, forKey: .target)
      self = .openApp(target: target)
    case "shell_command":
      let command = try container.decode(String.self, forKey: .command)
      self = .shellCommand(command: command)
    case "keys":
      // Decode directly into [String], remove parsing to [ParsedKey]
      let keyStrings = try container.decode([String].self, forKey: .keys)
      self = .keys(keys: keyStrings)  // Assign [String]
    default:
      // Improve error message for clarity
      let debugDesc =
        "Invalid action type '\(type)' found in config. Expected 'open_app', 'shell_command', or 'keys'."
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container, debugDescription: debugDesc)
    }
  }
}

class ConfigManager {
  static let shared = ConfigManager()

  private(set) var currentConfig: AppConfig?  // Stores the loaded config

  private var configPath: URL? {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let configFilePath =
      homeDir
      .appendingPathComponent(".config", isDirectory: true)
      .appendingPathComponent("HyprCuts", isDirectory: true)
      .appendingPathComponent("config.yaml")

    return configFilePath
  }

  // TODO: Define structs/classes to hold the parsed configuration (Task 10)

  private init() {
    // Private init for singleton pattern
    loadConfig()  // Attempt to load config on initialization
  }

  /// Attempts to load and parse the configuration file from `~/.config/HyprCuts/config.yaml`.
  func loadConfig() {
    currentConfig = nil  // Clear previous config first

    guard let path = configPath else {
      print("Error: Configuration path could not be determined.")
      // TODO: Handle error state (Task 12 - disable processing, update menu bar, log)
      return
    }

    print("INFO: Attempting to load config from: \(path.path)")  // TODO: Use proper logging (Task 29)

    // AC2.2: Ensure HyprCuts does NOT create the config file automatically.
    guard FileManager.default.fileExists(atPath: path.path) else {
      print("ERROR: Config file not found at \(path.path). Please create it.")  // TODO: Log error, update UI (Task 12)
      // TODO: Set an internal state indicating config is missing/invalid
      return
    }

    do {
      let configContent = try String(contentsOf: path, encoding: .utf8)
      print("INFO: Successfully read config file content.")  // TODO: Use proper logging

      // Parse YAML content using Yams (Task 10)
      let decoder = YAMLDecoder()
      let config = try decoder.decode(AppConfig.self, from: configContent)

      // Validate parsed config (Task 10a)
      guard KeyMapping.getKeyCode(for: config.masterKey) != nil else {
        print(
          "ERROR: Invalid configuration: 'master_key' ('\(config.masterKey)') does not correspond to a known key code."
        )
        handleConfigError()
        return
      }
      // AC3.2 validation: Ensure master_key is not a generic modifier represented by flags only.
      if KeyMapping.getFlags(for: config.masterKey) != nil
        && KeyMapping.stringToKeyCodeMap[config.masterKey.lowercased()] == nil
      {
        print(
          "ERROR: Invalid configuration: 'master_key' ('\(config.masterKey)') cannot be a generic modifier key name (like cmd, shift, opt, ctrl). Use specific keys like lcmd, rshift, etc. if needed, or a non-modifier key."
        )
        handleConfigError()
        return
      }
      // Further master key validation (e.g. against problematic keys) could go here (Task 19)

      // If all validation passes, store the config
      self.currentConfig = config

      print("SUCCESS: Configuration loaded and parsed.")

      // TODO: Add more validation as needed

    } catch let error as DecodingError {
      // More specific error handling for decoding issues
      print("ERROR: Failed to parse config file (YAML structure error).")
      // Print detailed decoding error information
      switch error {
      case .typeMismatch(let type, let context):
        print(
          "  Type mismatch: '\(type)' not found or doesn't match expected type at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        )
        print("  Debug description: \(context.debugDescription)")
      case .valueNotFound(let type, let context):
        print(
          "  Value not found: Expected '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        )
        print("  Debug description: \(context.debugDescription)")
      case .keyNotFound(let key, let context):
        print(
          "  Key not found: '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        )
        print("  Debug description: \(context.debugDescription)")
      case .dataCorrupted(let context):
        print(
          "  Data corrupted: Invalid format at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        )
        print("  Debug description: \(context.debugDescription)")
      @unknown default:
        print("  Unknown decoding error: \(error.localizedDescription)")
      }
      handleConfigError()  // Use a dedicated function for error state
    } catch {
      print("ERROR: Failed to read config file: \(error.localizedDescription)")  // TODO: Log error (Task 12, 29)
      handleConfigError()  // Use a dedicated function for error state
    }
  }

  /// Reloads the configuration from the file. (Called by file watcher - Task 11)
  func reloadConfig() {
    print("INFO: Reloading configuration...")  // TODO: Use proper logging
    currentConfig = nil  // Clear existing config before reloading
    loadConfig()
    // TODO: Notify other components (e.g., KeyboardMonitor) about the config change if necessary
    // TODO: Check if master key changed and update KeyboardMonitor if needed
    print("INFO: Config reload finished. Master Key: \(getMasterKey() ?? "Not Set")")
  }

  // MARK: - Validation Helpers

  private func isModifierOnly(key: String) -> Bool {
    // Check if the key exists *only* in the flags map and *not* in the keycode map.
    // This identifies generic modifiers like "cmd", "shift", etc.
    // Specific modifiers like "lcmd", "capslock" have both keycodes and flags, so they are allowed.
    let lowercasedKey = key.lowercased()
    let hasFlags = KeyMapping.stringToFlagsMap[lowercasedKey] != nil
    let hasKeyCode = KeyMapping.stringToKeyCodeMap[lowercasedKey] != nil
    return hasFlags && !hasKeyCode  // It's a modifier-only string if it has flags but no direct keycode
  }

  // MARK: - Error Handling Helper

  private func handleConfigError() {
    // Central place to manage state when config is invalid/missing (Task 12)
    self.currentConfig = nil
    // TODO: Update menu bar icon state (Task 12, 28)
    // TODO: Log the specific error properly (Task 12, 29)
    print("STATE: HyprCuts shortcut processing disabled due to config error.")
  }

  // MARK: - Accessors

  /// Returns the configured master key. (Task 10)
  func getMasterKey() -> String? {
    return currentConfig?.masterKey
  }

  /// Returns the master key tap timeout in milliseconds, defaulting to 200ms.
  func getMasterKeyTapTimeout() -> Int {
    // Provide default value here
    return currentConfig?.masterKeyTapTimeoutMs ?? 200
  }

  /// Returns whether to show sequence notifications.
  func shouldShowSequenceNotification() -> Bool? {
    return currentConfig?.showSequenceNotification
  }

  /// Returns the list of bindings.
  func getBindings() -> [Binding]? {
    return currentConfig?.bindings
  }

  // Add other accessors as needed
}
