# HyprCuts

**A lightweight macOS utility for triggering custom actions via rapid key sequences.**

HyprCuts runs in the background as a menu bar application, allowing you to define complex workflows and shortcuts triggered by holding a chosen 'master key' followed by a sequence of other keys. It uses a flexible tree-based configuration to map key sequences directly to actions like opening applications, running shell commands, or emulating keystrokes.

## Features

*   **Master Key Trigger:** Initiate sequences by holding a single, configurable master key.
*   **Tree-Based Key Bindings:** Define complex, nested key sequences using a YAML configuration file (`~/.config/HyprCuts/config.yaml`).
*   **Multiple Action Types:**
    *   `open_app`: Launch or focus applications by name or bundle ID.
    *   `shell_command`: Execute arbitrary shell commands.
    *   `keys`: Emulate sequences of key presses (including modifiers).
    *   `reset`: Reset the current key sequence state immediately.
*   **Background Operation:** Runs discreetly as a menu bar extra without a Dock icon.
*   **Sequence Feedback:** Optional visual overlay showing the currently typed key sequence.
*   **Efficient:** Designed for minimal resource usage.
*   **Configurable:** Customize master key, tap vs. hold timeout, and notification visibility.
*   **Automatic Config Reloading:** Monitors the configuration file for changes.
*   **Standard Behaviors:** Supports Launch-at-Login (via System Settings).

*Note: As of the current version, the `keys` action type is planned but not yet implemented.*

## Installation

Currently, HyprCuts needs to be built from source using Xcode.

1.  Clone the repository:
    ```bash
    git clone https://github.com/corpooo/HyprCuts.git
    cd HyprCuts
    ```
2.  Open the project in Xcode:
    ```bash
    xed .
    ```
    (or `open HyprCuts.xcodeproj` if an Xcode project file exists)
3.  Build the application using Xcode (Product > Build or Cmd+B).
4.  Run the application (Product > Run or Cmd+R). The built application can usually be found in Xcode's Derived Data directory or copied from the Products group in Xcode.

## Configuration

HyprCuts relies on a YAML configuration file located at:

```
~/.config/HyprCuts/config.yaml
```

**Important:** You must create this directory and file manually. HyprCuts will not create it for you.

### Structure

The configuration file has global settings and a main `bindings` tree.

```yaml
# ~/.config/HyprCuts/config.yaml

# --- Global Settings ---

# The primary key to hold down to initiate sequences.
# Can be any single key (letter, number, symbol, f-key, or specific modifier like 'lcmd', 'capslock').
# Cannot be a generic modifier like 'cmd' or 'shift'. See Key Representation below.
master_key: "'"

# (Optional) Differentiates a tap from a hold for the master key (milliseconds).
# If the master key is released within this time, it's treated as a normal key press.
# If held longer, HyprCuts captures it and starts listening for sequences. Default: 200
master_key_tap_timeout_ms: 200

# (Optional) Show a visual overlay of the key sequence being typed. Default: false
show_sequence_notification: true

# --- Key Bindings Tree ---
# Defines the sequences and their actions.
bindings:
  # Master -> O
  o:
    # Master -> O -> A (Leaf node with action)
    a: { type: "shell_command", command: "echo 'OA sequence completed'" }
    # Master -> O -> B (Leaf node with action)
    b: { type: "open_app", target: "Calculator" }
    # Master -> O -> C (Branch node)
    c:
      # Master -> O -> C -> E (Leaf node with reset action)
      e: { type: "reset" }
  # Master -> X (Leaf node with action)
  x: { type: "shell_command", command: "echo 'X sequence completed'" }
  # Master -> Y (Leaf node with NO action) - Sequence ends, state reverts.
  y: {}
  # Master -> Z (Branch node with NO action) - Waits for next key.
  z:
    # Master -> Z -> F (Leaf node with action)
    f: { type: "shell_command", command: "echo 'ZF sequence completed'" }
```

### Global Settings

*   `master_key` (Required): The key (string) you hold to start listening for sequences. See Key Representation.
*   `master_key_tap_timeout_ms` (Optional): Integer, milliseconds. Time to distinguish a tap from a hold for the `master_key`. Defaults to 200ms.
*   `show_sequence_notification` (Optional): Boolean (`true` or `false`). Enables the sequence feedback UI overlay. Defaults to `false`.
*   `sequence_timeout_ms` (Deprecated): This setting from v1 is ignored. Sequences persist as long as the `master_key` is held.

### Bindings Tree

The `bindings` key contains a nested dictionary representing your key sequences.

*   **Keys:** Each key in the dictionary is a string representing a key press in the sequence (e.g., `"o"`, `"f1"`, `"lshift"`). See Key Representation.
*   **Values (Nodes):** Each key maps to either:
    *   **Branch Node:** A nested dictionary containing further key bindings (e.g., the `c:` and `z:` nodes in the example). When a branch node is reached, HyprCuts waits for the next key.
    *   **Leaf Node:** An Action Object defining what happens when the sequence ends here (e.g., `a: { ... }`). Or an empty dictionary (`{}`) signifying a leaf node with no action (e.g., the `y:` node). When a leaf node is reached, the specified action (if any) is executed, and the sequence state reverts to the parent node.

### Key Representation

Keys used in `master_key` and within the `bindings` tree should use the following string representations:

*   **Letters:** `a`, `b`, ..., `z`
*   **Numbers:** `0`, `1`, ..., `9`
*   **Symbols:** Use the symbol directly (e.g., `/`, `-`, `=`) or common names (e.g., `slash`, `minus`, `equal`, `period`, `comma`, `backslash`, `quote`, `grave`, `leftbracket`, `rightbracket`, `semicolon`).
*   **Special Keys:** `return` (or `enter`), `tab`, `space` (or `spc`), `escape` (or `esc`), `delete` (or `backspace`, `bspc`), `forwarddelete` (or `del`), `home`, `end`, `pageup` (or `pgup`), `pagedown` (or `pgdn`), `help`, `insert`.
*   **Arrow Keys:** `left`, `right`, `up`, `down`.
*   **Function Keys:** `f1`, `f2`, ..., `f20`.
*   **Specific Modifier Keys:** `lcmd`, `rcmd`, `lshift`, `rshift`, `lopt`, `ropt`, `lctrl`, `rctrl`, `caps` (or `capslock`), `fn`. (These can be used as sequence keys or even as the `master_key`).
*   **Generic Modifiers:** `cmd`, `shift`, `opt`, `ctrl` should **not** be used as the `master_key` or sequence keys themselves. They are used *within* the `keys` action type (see below).

### Action Object Format

All actions must be defined as objects with a `type` field and corresponding arguments:

*   **`open_app`**: Opens or focuses an application.
    *   `type: "open_app"`
    *   `target` (String): Application name (e.g., `"Safari"`) or bundle ID (e.g., `"com.apple.Safari"`).
*   **`shell_command`**: Executes a shell command.
    *   `type: "shell_command"`
    *   `command` (String): The command to execute (e.g., `"echo 'Hello'"`).
*   **`reset`**: Resets the sequence state.
    *   `type: "reset"` (Takes no other arguments).
*   **`keys`** *(Planned)*: Emulates key presses.
    *   `type: "keys"`
    *   `keys` (Array of Strings): An array of keys/combinations to press sequentially. Each string can be a single key (e.g., `"a"`) or a modifier combo using `+` (e.g., `"lcmd+c"`, `"lshift+a"`). Use modifier abbreviations like `lcmd`, `lshift`, `lopt`, `lctrl`.

## Usage

1.  **Ensure Configuration:** Create your `~/.config/HyprCuts/config.yaml` file.
2.  **Run HyprCuts:** Launch the application. It will appear in the menu bar.
3.  **Grant Permissions:** If prompted, grant Accessibility permissions in System Settings.
4.  **Trigger Sequence:** Press and *hold* your configured `master_key`.
5.  **Type Sequence:** While holding the `master_key`, type the keys defined in your `bindings` tree.
6.  **Action Execution:** When a sequence matching a leaf node with an action is completed, the action executes. The internal state typically reverts to the parent node, allowing you to continue sequences (e.g., after `Master -> O -> A`, the state is `Master -> O`, ready for `B` or `C`).
7.  **Release Master Key:** Releasing the `master_key` at any time resets the sequence state completely.
8.  **Reset Action:** Using the `{type: "reset"}` action also resets the state back to the root immediately.
9.  **Feedback:** If `show_sequence_notification` is `true`, an overlay will show the sequence as you type it, persisting briefly after completion.

## Requirements

*   macOS 13 (Ventura) or newer.

## Permissions

HyprCuts requires **Accessibility** permissions to monitor keyboard events system-wide.

*   On the first launch, HyprCuts should prompt you to grant these permissions.
*   If you deny or dismiss the prompt, HyprCuts' core functionality will be disabled.
*   You can grant permissions manually via:
    `System Settings > Privacy & Security > Accessibility`
*   Find HyprCuts in the list and enable the toggle. You might need to restart HyprCuts after granting permissions.
*   The menu bar icon will indicate if permissions are missing.

## Building from Source

1.  Clone the repository.
2.  Open the project in Xcode.
3.  Select the "HyprCuts" scheme.
4.  Build and run (Cmd+R).

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

## License

(Assuming MIT - can be changed if needed)
This project is licensed under the MIT License. See the LICENSE file for details. 
