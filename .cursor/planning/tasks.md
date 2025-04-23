# HyprCuts - Task List (v2 Focus)

This list tracks the implementation tasks derived from the v2 Acceptance Criteria. Items completed under v1 are marked, but may require rework for v2 compatibility.

## 1. Core & General Setup

- [ ] **1** **(v2 AC2.1)** Implement core logic to define and trigger actions via master key + key sequence (tree-based):
  - [x] **1a** **(v1 AC1.1, v1 AC3.4)** Implement initial core logic: Detect `master_key` press/hold and suppress its default OS behavior. (Verify v2 compatibility)
  - [x] **1b** **(v2 AC2.2-AC2.6)** Implement v2 key sequence listening framework based on tree traversal (child/root lookup), state persistence/reset on master key release. (Ancestor lookup deferred, see TODO)
- [x] **2** **(v1 AC1.2)** Set up the application to run as a background utility process.
- [x] **3** **(v1 AC7.1, v1 AC7.2)** Implement Accessibility permissions check on startup.
- [x] **4** **(v1 AC7.2)** Provide user guidance to grant Accessibility permissions if missing.
- [ ] **5** **(v1 AC7.3, v1 AC7.4)** Implement standard macOS launch-at-login functionality.
- [x] **6** **(v1 AC8.1)** Ensure project targets macOS 13 (Ventura) or newer.
- [ ] **7** **(v1 AC8.2)** Profile and optimize for minimal resource usage (consider v2 processing).

## 2. Configuration Management (v2 Schema)

- [x] **8** **(v2 AC1.1, v2 AC1.4)** Implement logic to read and parse the **tree-based** `bindings` structure from `~/.config/HyprCuts/config.yaml`.
- [x] **9** **(v1 AC2.2)** Ensure HyprCuts does _not_ create the config file automatically.
- [x] **10** **(v2 AC1.1, v2 AC1.2, v2 AC1.4)** Define and parse the YAML structure for global settings (`master_key`, `show_sequence_notification`, `master_key_tap_timeout_ms`) and the **nested `bindings` tree using only object format for actions**.
  - [x] **10a** Add validation to prevent modifier-only keys from being set as `master_key`.
- [ ] **11** **(v1 AC6.1)** Implement file monitoring for `config.yaml` and automatic reloading (verify v2 parsing compatibility).
- [ ] **12** **(v1 AC6.2)** Implement robust error handling for missing/invalid `config.yaml` (disable processing, update menu bar, log errors - verify v2 impact).
- [x] **13** **(v2 AC1.3, v2 AC5.1)** Remove handling and references to the deprecated `sequence_timeout_ms` setting.
- [x] **14** **(v2 AC5.2)** Remove parsing logic for the old string-based action format.

## 3. Key Input & Sequence Processing (v2 Logic)

- [x] **15** **(v1 AC3.1, v1 AC3.2, v1 AC3.3)** Define and handle standardized string representations for all keys (Verify v2 compatibility).
- [x] **16** **(v1 AC3.6)** Allow any defined key (including modifiers) as keys within the `bindings` tree structure.
- [x] **17** **(v1 AC3.9 -> Reworked in 1b)** Implement key sequence matching (Replaced by **Task 1b** for v2 tree traversal).
- [ ] **18** **(v2 AC2.3c, v2 AC4.3)** Implement feedback for invalid keys in the sequence (toast/log).
- [ ] **19** **(v1 AC6.5)** Implement warning mechanism (log/notification) for potentially problematic `master_key` choices.
- [ ] **23a** Parse `keys` array from action object.
- [ ] **24** **(v1 AC6.3 -> v2 AC3.3)** Implement action failure handling (toast notification, logging) (Verify v2 compatibility).
- [x] **25** **(v2 AC1.5, v2 AC2.5, v2 AC3.2)** Implement the new `reset` action type (Definition and basic execution added).

## 4. Action Implementation (v2 Actions)

- [x] **20** **(v1 AC4.1)** Create base action execution framework supporting different types (Verify v2 compatibility).
- [x] **21** **(v1 AC4.2)** Implement `open_app` action (using object format).
  - [x] **21a** Find app by name or bundle ID.
  - [x] **21b** Bring to front if running.
  - [x] **21c** Launch if not running.
- [x] **22** **(v1 AC4.3)** Implement `shell_command` action (using object format).
  - [x] **22a** Execute command string with user permissions.
- [ ] **23** **(v1 AC4.4 -> v2 AC1.2)** Implement `keys` action (using object format).

## 5. UI/UX (v2 Updates)

- [x] **26** **(v1 AC5.1)** Set up application to run as a menu bar extra without a Dock icon.
- [ ] **27** **(v1 AC5.2)** Build the menu bar menu:
  - [ ] **27a** `Enable`/`Disable` toggle + visual state indication.
  - [ ] **27b** `Restart` function.
  - [ ] **27c** `Reload Config` function.
  - [ ] **27d** Display current `master_key`.
  - [ ] **27e** `Quit` function.
- [ ] **28** **(v2 AC4.3)** Implement/Update toast notification system:
  - [ ] **28a** Show current valid sequence path (e.g., "O > C") if `show_sequence_notification` is true.
  - [ ] **28b** Show invalid key feedback (Task 18 related).
  - [ ] **28c** Show action execution failures (Task 24 related).
- [ ] **29** **(v1 AC6.2, v1 AC7.2)** Implement menu bar icon state changes for configuration errors or missing permissions.
- [ ] **30** **(v2 AC4.1)** Remove UI elements related to `sequence_timeout_ms`.

## 6. Logging & Documentation

- [ ] **31** **(v1 AC6.4)** Set up logging to `~/Library/Logs/HyprCuts/HyprCuts.log`.
- [ ] **32** Ensure relevant events are logged (config errors, action failures, invalid keys, sequence resets etc.).
- [ ] **33** **(v2 AC5.3)** Update documentation (README, comments) to reflect v2 schema and behavior.
