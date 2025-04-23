# HyprCuts - Task List

This list tracks the implementation tasks derived from the v1 Acceptance Criteria.

## 1. Core & General Setup

- [ ] **1** **(AC1.1)** Implement core logic to define and trigger actions via master key + key sequence:
  - [x] **1a** **(AC1.1, AC3.4)** Implement initial core logic: Detect `master_key` press/hold and suppress its default OS behavior.
  - [ ] **1b** **(AC1.1, AC3.5)** Implement key sequence listening framework activated by `master_key` hold and basic action triggering mechanism. (Current action: Debug print key event)
- [x] **2** **(AC1.2)** Set up the application to run as a background utility process.
- [x] **3** **(AC7.1, AC7.2)** Implement Accessibility permissions check on startup.
- [x] **4** **(AC7.2)** Provide user guidance to grant Accessibility permissions if missing.
- [ ] **5** **(AC7.3, AC7.4)** Implement standard macOS launch-at-login functionality.
- [x] **6** **(AC8.1)** Ensure project targets macOS 13 (Ventura) or newer.
- [ ] **7** **(AC8.2)** Profile and optimize for minimal resource usage.

## 2. Configuration Management

- [x] **8** **(AC2.1)** Implement logic to read configuration from `~/.config/HyprCuts/config.yaml`.
- [x] **9** **(AC2.2)** Ensure HyprCuts does _not_ create the config file automatically.
- [x] **10** **(AC2.3, AC2.4, AC2.5, AC2.6, AC2.7)** Define and parse the YAML structure for global settings (`master_key`, `sequence_timeout_ms` [for sequence input], `show_sequence_notification`, `master_key_tap_timeout_ms` [for tap/hold detection]) and the `bindings` list (including optional `description`, `keys`, `action` object).
  - [x] **10a** Add validation to prevent modifier-only keys (Cmd, Shift, Opt, Ctrl, Caps Lock, Fn) from being set as `master_key`.
- [ ] **11** **(AC6.1)** Implement file monitoring for `config.yaml` and automatic reloading.
- [ ] **12** **(AC6.2)** Implement robust error handling for missing/invalid `config.yaml` (disable processing, update menu bar, log errors).

## 3. Key Input & Sequence Processing

- [x] **13** **(AC3.1, AC3.2, AC3.3)** Define and handle standardized string representations for all keys, including modifiers (`lcmd`/`cmd`, `rcmd`, etc.) and special keys (`enter`, `tab`, `f1`, etc.).
- [ ] **14** **(AC3.1)** Allow any single key (including modifiers) to be configured as `master_key`.
- [ ] **15** **(AC3.6)** Allow any defined key (including modifiers) within `keys` arrays.
- [ ] **16** **(AC3.8)** Implement key sequence timeout logic based on `sequence_timeout_ms` (time between keys in sequence).
- [x] **16a** Implement master key tap/hold detection timeout based on `master_key_tap_timeout_ms`.
- [ ] **17** **(AC3.9)** Implement key sequence matching with support for branching/resetting based on user input.
- [ ] **18** **(AC3.10)** Implement feedback and cancellation for invalid keys in the sequence.
- [ ] **19** **(AC6.5)** Implement warning mechanism (log/notification) for potentially problematic `master_key` choices.

## 4. Action Implementation

- [ ] **20** **(AC4.1)** Create base action execution framework supporting different types.
- [ ] **21** **(AC4.2)** Implement `open_app` action:
  - [ ] **21a** Find app by name or bundle ID.
  - [ ] **21b** Bring to front if running.
  - [ ] **21c** Launch if not running.
- [ ] **22** **(AC4.3)** Implement `shell_command` action:
  - [ ] **22a** Execute command string with user permissions.
- [ ] **23** **(AC4.4)** Implement `keys` action:
  - [ ] **23a** Parse `keys` array.
  - [ ] **23b** Emulate sequential key press-and-release events.
  - [ ] **23c** Support modifier combinations (e.g., `lcmd+C`).
- [ ] **24** **(AC6.3)** Implement action failure handling (toast notification, logging).

## 5. UI/UX

- [x] **25** **(AC5.1)** Set up application to run as a menu bar extra without a Dock icon.
- [ ] **26** **(AC5.2)** Build the menu bar menu:
  - [ ] **26a** `Enable`/`Disable` toggle + visual state indication.
  - [ ] **26b** `Restart` function.
  - [ ] **26c** `Reload Config` function.
  - [ ] **26d** Display current `master_key` (read from config; initial dev placeholder is single quote `'`).
  - [ ] **26e** `Quit` function.
- [ ] **27** **(AC5.3, AC3.7, AC3.10, AC6.3)** Implement toast notification system for:
  - [ ] **27a** Key sequence input feedback (if `show_sequence_notification` is true).
  - [ ] **27b** Invalid key sequence input.
  - [ ] **27c** Action execution failures.
- [ ] **28** **(AC6.2, AC7.2)** Implement menu bar icon state changes for configuration errors or missing permissions.

## 6. Logging

- [ ] **29** **(AC6.4)** Set up logging to `~/Library/Logs/HyprCuts/HyprCuts.log`.
- [ ] **30** Ensure relevant events are logged (config errors, action failures, etc.).
