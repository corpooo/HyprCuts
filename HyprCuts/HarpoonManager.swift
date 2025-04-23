//
//  HarpoonManager.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 23.04.2025.
//

import Foundation
import os

class HarpoonManager {
  static let shared = HarpoonManager()  // Make it a shared instance

  // Notification posted when pairings are changed
  static let pairingsDidChangeNotification = Notification.Name("HarpoonManager.pairingsDidChange")

  private var pairings: [String: String] = [:]
  private let persistenceURL: URL
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HarpoonManager")

  init() {
    // Construct the path to ~/.config/hyprcuts/harpoon_state.json
    guard
      let configDir = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first?
      .appendingPathComponent("hyprcuts", isDirectory: true)
    else {
      fatalError("Could not construct config directory path.")  // Or handle more gracefully
    }
    self.persistenceURL = configDir.appendingPathComponent("harpoon_state.json")

    // Ensure the directory exists
    do {
      try FileManager.default.createDirectory(
        at: configDir, withIntermediateDirectories: true, attributes: nil)
    } catch {
      logger.error("Failed to create config directory: \(error.localizedDescription)")
      // Proceed without persistence? Or fatalError? For now, proceed.
    }

    loadPairings()
  }

  // MARK: - Persistence

  private func loadPairings() {
    do {
      // Check if file exists before attempting to read
      guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
        logger.info(
          "Harpoon state file not found at \(self.persistenceURL.path). Starting with empty pairings."
        )
        return  // No file yet, start fresh
      }

      let data = try Data(contentsOf: persistenceURL)
      let decoder = JSONDecoder()
      self.pairings = try decoder.decode([String: String].self, from: data)
      logger.info(
        "Successfully loaded \(self.pairings.count) harpoon pairings from \(self.persistenceURL.path)."
      )
    } catch {
      logger.error(
        "Failed to load harpoon pairings from \(self.persistenceURL.path): \(error.localizedDescription)"
      )
      // Decide on recovery strategy: start fresh, notify user, etc.
      self.pairings = [:]  // Start fresh for now
    }
  }

  private func savePairings() {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted  // Optional: for readability
      let data = try encoder.encode(pairings)
      try data.write(to: persistenceURL, options: .atomic)
      logger.info(
        "Successfully saved \(self.pairings.count) harpoon pairings to \(self.persistenceURL.path)."
      )
      // Post notification on the main thread for UI observers
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: HarpoonManager.pairingsDidChangeNotification, object: nil)
      }
    } catch {
      logger.error(
        "Failed to save harpoon pairings to \(self.persistenceURL.path): \(error.localizedDescription)"
      )
      // Notify user? Retry?
    }
  }

  // MARK: - Public API

  /// Sets or updates a pairing for a given slot key.
  func setPairing(forKey key: String, bundleIdentifier: String) {
    logger.debug("Setting harpoon slot '\(key)' to '\(bundleIdentifier)'")
    pairings[key] = bundleIdentifier
    savePairings()  // Persist after modification
    // TODO: Post notification for menu update?
  }

  /// Removes a pairing for a given slot key.
  func removePairing(forKey key: String) {
    logger.debug("Removing harpoon slot '\(key)'")
    if pairings.removeValue(forKey: key) != nil {
      savePairings()  // Persist only if something was actually removed
      // TODO: Post notification for menu update?
    } else {
      logger.warning("Attempted to remove non-existent harpoon slot '\(key)'")
    }
  }

  /// Retrieves the bundle identifier for a given slot key.
  func getPairing(forKey key: String) -> String? {
    return pairings[key]
  }

  /// Retrieves all current pairings.
  func getAllPairings() -> [String: String] {
    return pairings
  }

  /// Removes all pairings.
  func clearAllPairings() {
    logger.info("Clearing all harpoon pairings.")
    pairings.removeAll()
    savePairings()  // Persist after clearing
    // TODO: Post notification for menu update?
  }
}
