# HyprCuts - Task List

This list tracks the implementation tasks derived from the v1 Acceptance Criteria.

## 1. Core & General Setup
- [ ] **(AC1.1)** Implement core logic to define and trigger actions via master key + sequence.
- [x] **(AC1.2)** Set up the application to run as a background utility process.
- [ ] **(AC7.1, AC7.2)** Implement Accessibility permissions check on startup.
- [ ] **(AC7.2)** Provide user guidance to grant Accessibility permissions if missing.
- [ ] **(AC7.3, AC7.4)** Implement standard macOS launch-at-login functionality.
- [x] **(AC8.1)** Ensure project targets macOS 13 (Ventura) or newer.
- [ ] **(AC8.2)** Profile and optimize for minimal resource usage.

## 2. Configuration Management
- [ ] **(AC2.1)** Implement logic to read configuration from `~/.config/HyprCuts/config.yaml`.
- [ ] **(AC2.2)** Ensure HyprCuts does *not* create the config file automatically.
- [ ] **(AC2.3, AC2.4, AC2.5, AC2.6, AC2.7)** Define and parse the YAML structure for global settings (`master_key`, `sequence_timeout_ms`, `show_sequence_notification`) and the `shortcuts` list (including `name`, `sequence`, `action` object).
- [ ] **(AC6.1)** Implement file monitoring for `config.yaml` and automatic reloading.
- [ ] **(AC6.2)** Implement robust error handling for missing/invalid `config.yaml` (disable processing, update menu bar, log errors).

## 3. Key Input & Sequence Processing
- [ ] **(AC3.1, AC3.2, AC3.3)** Define and handle standardized string representations for all keys, including modifiers (`lcmd`, `rcmd`, etc.) and special keys (`enter`, `tab`, `f1`, etc.).
- [ ] **(AC3.1)** Allow any single key (including modifiers) to be configured as `master_key`.
- [ ] **(AC3.4)** Implement suppression of the `master_key`'s default OS function while held.
- [ ] **(AC3.5)** Implement core sequence listening logic activated by holding the `master_key`.
- [ ] **(AC3.6)** Allow any defined key (including modifiers) within sequence arrays.
- [ ] **(AC3.8)** Implement sequence timeout logic based on `sequence_timeout_ms`.
- [ ] **(AC3.9)** Implement sequence matching with support for branching/resetting based on user input.
- [ ] **(AC3.10)** Implement feedback and cancellation for invalid sequence keys.
- [ ] **(AC6.5)** Implement warning mechanism (log/notification) for potentially problematic `master_key` choices.

## 4. Action Implementation
- [ ] **(AC4.1)** Create base action execution framework supporting different types.
- [ ] **(AC4.2)** Implement `open_app` action:
    - [ ] Find app by name or bundle ID.
    - [ ] Bring to front if running.
    - [ ] Launch if not running.
- [ ] **(AC4.3)** Implement `shell_command` action:
    - [ ] Execute command string with user permissions.
- [ ] **(AC4.4)** Implement `keys` action:
    - [ ] Parse `keys` array.
    - [ ] Emulate sequential key press-and-release events.
    - [ ] Support modifier combinations (e.g., `lcmd+C`).
- [ ] **(AC6.3)** Implement action failure handling (toast notification, logging).

## 5. UI/UX
- [x] **(AC5.1)** Set up application to run as a menu bar extra without a Dock icon.
- [ ] **(AC5.2)** Build the menu bar menu:
    - [ ] `Enable`/`Disable` toggle + visual state indication.
    - [ ] `Restart` function.
    - [ ] `Reload Config` function.
    - [ ] Display current `master_key`.
    - [ ] `Quit` function.
- [ ] **(AC5.3, AC3.7, AC3.10, AC6.3)** Implement toast notification system for:
    - [ ] Sequence input feedback (if `show_sequence_notification` is true).
    - [ ] Invalid sequence input.
    - [ ] Action execution failures.
- [ ] **(AC6.2, AC7.2)** Implement menu bar icon state changes for configuration errors or missing permissions.

## 6. Logging
- [ ] **(AC6.4)** Set up logging to `~/Library/Logs/HyprCuts/HyprCuts.log`.
- [ ] Ensure relevant events are logged (config errors, action failures, etc.). 
