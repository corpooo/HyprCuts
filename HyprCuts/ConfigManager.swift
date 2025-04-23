//
//  ConfigManager.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import Foundation
import Yams  // Make sure Yams is added via SPM

// NOTE: Add 'Yams' dependency via SPM: https://github.com/jpsim/Yams.git
// import Yams

// MARK: - Configuration Data Structures (Task 10)

struct AppConfig: Decodable {
  let masterKey: String
  let sequenceTimeoutMs: Int // Keep this for sequence timeout (Task 16)
  let masterKeyTapTimeoutMs: Int? // Use this for tap/hold differentiation, optional
  let showSequenceNotification: Bool
  let bindings: [Binding]

  enum CodingKeys: String, CodingKey {
    case masterKey = "master_key"
    case sequenceTimeoutMs = "sequence_timeout_ms" // Keep original key
    case masterKeyTapTimeoutMs = "master_key_tap_timeout_ms" // Add the correct key
    case showSequenceNotification = "show_sequence_notification"
    case bindings
  }
}

struct Binding: Decodable {
  let keys: [String]
  let action: Action
  let description: String?  // Optional description

  // Add a property to store the parsed key sequence after decoding
  var parsedKeys: [(keyCode: CGKeyCode, modifiers: CGEventFlags)]? = nil
}

enum Action: Decodable {
  case openApp(target: String)
  case shellCommand(command: String)
  case keys(keys: [String])

  // Custom Decodable implementation for action types
  private enum CodingKeys: String, CodingKey {
    case type, target, command, keys
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
      let keys = try container.decode([String].self, forKey: .keys)
      self = .keys(keys: keys)
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
      var config = try decoder.decode(AppConfig.self, from: configContent)

      // Validate parsed config (Task 10a)
      guard let masterKeyCode = KeyMapping.getKeyCode(for: config.masterKey) else {
          print(
            "ERROR: Invalid configuration: 'master_key' ('\(config.masterKey)') does not correspond to a known key code."
          )
          handleConfigError()
          return
      }
      // AC3.2 validation: Ensure master_key is not a generic modifier represented by flags only.
      if KeyMapping.getFlags(for: config.masterKey) != nil && KeyMapping.stringToKeyCodeMap[config.masterKey.lowercased()] == nil {
           print(
             "ERROR: Invalid configuration: 'master_key' ('\(config.masterKey)') cannot be a generic modifier key name (like cmd, shift, opt, ctrl). Use specific keys like lcmd, rshift, etc. if needed, or a non-modifier key."
           )
           handleConfigError()
           return
      }
      // Further master key validation (e.g. against problematic keys) could go here (Task 19)

      // Parse and validate key bindings (Task 13 integration)
      for i in 0..<config.bindings.count {
          var parsedSequence: [(keyCode: CGKeyCode, modifiers: CGEventFlags)] = []
          for keyString in config.bindings[i].keys {
              guard let parsedKey = KeyMapping.parseBindingKeyCombo(keyString: keyString) else {
                  print("ERROR: Invalid key sequence in binding #\(i+1) ('\(config.bindings[i].description ?? "No description")'): Could not parse key '\(keyString)'.")
                  // TODO: Log error properly (Task 12, 29)
                  handleConfigError() // Invalidate the whole config for now
                  return
              }
              parsedSequence.append(parsedKey)
          }
          // Assign the successfully parsed sequence to the binding
          config.bindings[i].parsedKeys = parsedSequence
      }

      // If all validation passes, store the config
      self.currentConfig = config

      print("SUCCESS: Configuration loaded and parsed.")

      // TODO: Add more validation as needed

    } catch let error as DecodingError {
      // More specific error handling for decoding issues
      print(
        "ERROR: Failed to parse config file (YAML structure error): \(error.localizedDescription)")
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
    return hasFlags && !hasKeyCode // It's a modifier-only string if it has flags but no direct keycode
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

  /// Returns the sequence timeout in milliseconds (for time between sequence keys).
  func getSequenceTimeout() -> Int? {
    // Accessor for the other timeout value
    return currentConfig?.sequenceTimeoutMs
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
