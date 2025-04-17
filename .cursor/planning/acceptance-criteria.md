## HyprCuts - Acceptance Criteria (v1)

This document outlines the acceptance criteria for the initial version of the HyprCuts macOS application.

**1. General / Core Concept**

* **AC1.1:** The application, named HyprCuts, allows users to define and trigger custom actions by holding a single global 'master key' and then pressing a sequence of keys.
* **AC1.2:** HyprCuts runs as a background utility process.

**2. Configuration**

* **AC2.1:** All configuration is managed via a single YAML file located at `~/.config/HyprCuts/config.yaml`.
* **AC2.2:** HyprCuts does *not* create this configuration file automatically; the user must create it manually.
* **AC2.3:** The configuration file defines global settings and a list of shortcut definitions.
* **AC2.4:** The configuration includes a global `master_key` setting.
* **AC2.5:** The configuration includes a global `sequence_timeout_ms` setting (integer, milliseconds) defining the maximum time allowed between key presses in a sequence.
* **AC2.6:** The configuration includes a global boolean setting `show_sequence_notification` to enable/disable the sequence input feedback toast.
* **AC2.7:** Each shortcut definition in the `shortcuts` list includes a `name` (string), a `sequence` (array of key strings), and an `action` (object defining the action type and parameters).

**3. Master Key & Sequence Input**

* **AC3.1:** The global `master_key` can be configured to be *any* single key, including modifier keys.
* **AC3.2:** Modifier keys used as the `master_key` or in sequences must be specified using standard abbreviations: `lcmd`, `rcmd`, `lshift`, `rshift`, `lopt`, `ropt`, `lctrl`, `rctrl`, `caps` (Caps Lock), `fn` (Function key).
* **AC3.3:** Non-alphanumeric keys (e.g., `enter`, `tab`, `space`, `escape`, `delete`, arrow keys, function keys `f1`-`f12`, etc.) must have standardized string representations for use in the `master_key` setting and `sequence` arrays.
* **AC3.4:** While the `master_key` is held down, its standard OS/key function must be suppressed.
* **AC3.5:** After the `master_key` is pressed and held, HyprCuts listens for a sequence of key presses defined in the configuration.
* **AC3.6:** Keys allowed in the `sequence` array can be any key, represented by the standardized strings (including modifiers if pressed as part of the sequence, though the primary use case involves non-modifier keys).
* **AC3.7:** If `show_sequence_notification` is true, a temporary visual indicator (e.g., a toast notification) appears while the `master_key` is held, showing the sequence keys as they are pressed.
* **AC3.8:** If the time between sequence key presses exceeds `sequence_timeout_ms`, the current sequence input attempt is cancelled.
* **AC3.9:** Sequence matching supports branching: If a user types a partial sequence (e.g., `O A`) and the next key (`R`) does not continue any sequence starting with `O A` but *does* start a different defined sequence (e.g., `R E C`), the input state resets to listen for the `R E C` sequence.
* **AC3.10:** If, during sequence input, the user presses a key that does not validly continue the current sequence path *and* does not start any *new* defined sequence, visual feedback (e.g., distinct toast/indicator) must be shown indicating an invalid/unrecognized sequence, and the sequence input attempt is cancelled.

**4. Actions**

* **AC4.1:** Three types of actions must be supported, specified by the `type` field within the `action` object: `open_app`, `shell_command`, `keys`.
* **AC4.2:** `open_app`:
    * Requires a `target` field specifying the application by either its name (e.g., `"Safari"`) or its bundle ID (e.g., `"com.apple.Safari"`).
    * If the target application is already running, this action must bring the application to the foreground (focus it) rather than launching a new instance.
    * If the target application is not running, it should be launched.
* **AC4.3:** `shell_command`:
    * Requires a `command` field containing the shell command string to execute.
    * The command must be executed with the standard permissions of the currently logged-in user.
* **AC4.4:** `keys`:
    * Requires a `keys` field containing an array of strings.
    * Each string in the array represents a key press event to be emulated.
    * Strings can represent single keys (e.g., `"a"`, `"enter"`) or modifier combinations (e.g., `"lcmd+C"`, `"lshift+lopt+T"`). Modifiers use the standard abbreviations.
    * The key events in the array are executed sequentially: the system simulates the full press-and-release of the first item, then the full press-and-release of the second, and so on.

**5. UI/UX (Menu Bar, Notifications)**

* **AC5.1:** HyprCuts runs as a menu bar (status bar) application, without a Dock icon during normal operation.
* **AC5.2:** The menu bar icon provides a menu with the following options:
    * `Enable`/`Disable`: Toggles the master key listening on/off. State should be visually indicated (e.g., checkmark).
    * `Restart`: Restarts the HyprCuts background process.
    * `Reload Config`: Manually triggers a reload of the configuration file.
    * Display of the current `master_key` (e.g., "Master Key: lcmd").
    * `Quit`: Terminates the HyprCuts application.
* **AC5.3:** Toast notifications are used for feedback (if enabled):
    * Showing the sequence being typed.
    * Indicating an invalid key was pressed during sequence input.
    * Indicating when an action fails to execute.

**6. Error Handling & Logging**

* **AC6.1:** HyprCuts automatically monitors the `config.yaml` file for changes and reloads it in the background.
* **AC6.2:** If the `config.yaml` file is missing or contains invalid YAML syntax or structural errors (e.g., missing `master_key`), HyprCuts must:
    * Disable shortcut processing.
    * Indicate an error state via its menu bar icon (e.g., change icon appearance, add an error message to the menu).
    * Log the specific configuration error(s).
* **AC6.3:** If a configured action fails during execution (e.g., `open_app` target not found, `shell_command` returns error, `keys` emulation fails), a toast notification must be shown to the user indicating the failure. The error should also be logged.
* **AC6.4:** Logs are written to `~/Library/Logs/HyprCuts/HyprCuts.log`.
* **AC6.5:** If the user selects a `master_key` known to potentially conflict with critical OS functions, HyprCuts should attempt to notify the user (mechanism TBD - perhaps logging or a one-time notification if possible during config reload).

**7. System Integration**

* **AC7.1:** HyprCuts must check for macOS Accessibility permissions on startup.
* **AC7.2:** If Accessibility permissions are not granted, HyprCuts must:
    * Disable shortcut processing.
    * Indicate the missing permissions state via the menu bar icon/menu.
    * Provide a mechanism (e.g., a dialog prompt on launch or a menu bar option) to guide the user to `System Settings > Privacy & Security > Accessibility` to grant permissions.
* **AC7.3:** HyprCuts must support launching automatically when the user logs in.
* **AC7.4:** The launch-at-login behaviour must be configurable by the user (standard macOS mechanisms for login items are acceptable).

**8. Non-Functional Requirements**

* **AC8.1:** Requires macOS 13 (Ventura) or newer.
* **AC8.2:** Must be lightweight and have minimal impact on system resources (CPU, Memory) during idle listening and action execution.
