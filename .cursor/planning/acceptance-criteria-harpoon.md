# Acceptance Criteria: Harpoon Feature

## Goal

To implement a set of actions (`harpoon:set`, `harpoon:rm`, `harpoon:go`, `harpoon:reset`) that allow users to quickly create, remove, and jump to application "bookmarks" (pairings), similar in concept to the Harpoon plugin for Neovim but applied to macOS applications.

## Definitions

-   **Harpoon Pairing:** A persistent association between a specific "slot key" and a macOS application's bundle identifier.
-   **Slot Key:** The final key pressed in a `harpoon:set/rm/go` sequence, which identifies the specific pairing slot. Any key on the keyboard can potentially be used as a slot key.
-   **Sequence:** A series of keys pressed after the `master_key`, as defined in `config.yaml`.

## Core Actions

### 1. `harpoon:set`

-   **Trigger:** User executes a sequence defined in `config.yaml` ending with a specific `slot key` node that contains `{ type: "harpoon:set" }`.
-   **Behavior:**
    -   Identifies the frontmost application at the time the sequence is completed.
    -   Retrieves the bundle identifier of the frontmost application.
    -   Creates or updates a pairing between the final `slot key` of the sequence and the application's bundle identifier.
    -   Persists this pairing to storage.
-   **Feedback:** Displays a temporary notification confirming the pairing (e.g., "Harpoon: Set slot 'X' to 'AppName'").
-   **Configuration Example:**
    ```yaml
    bindings:
      h: # Master -> H
        s: # Master -> H -> S
          "1": { type: "harpoon:set" } # Master -> H -> S -> 1 sets slot '1'
          a: { type: "harpoon:set" } # Master -> H -> S -> a sets slot 'a'
    # User presses: Master -> H -> S -> 1 (while Safari is active)
    # Result: Slot '1' is now paired with 'com.apple.Safari'
    ```

### 2. `harpoon:rm`

-   **Trigger:** User executes a sequence defined in `config.yaml` ending with a specific `slot key` node that contains `{ type: "harpoon:rm" }`.
-   **Behavior:**
    -   Identifies the final `slot key` of the sequence.
    -   Checks if a pairing exists for that `slot key`.
    -   If a pairing exists, it removes it from the stored pairings.
    -   Persists the updated pairings list to storage.
-   **Feedback:**
    -   If a pairing was removed: Displays a temporary notification (e.g., "Harpoon: Removed pairing for slot 'X'").
    -   If no pairing existed: Displays a temporary notification (e.g., "Harpoon: No pairing found for slot 'X'").
-   **Configuration Example:**
    ```yaml
    bindings:
      h: # Master -> H
        r: # Master -> H -> R (Remove mode)
          "1": { type: "harpoon:rm" } # Master -> H -> R -> 1 removes slot '1'
          a: { type: "harpoon:rm" } # Master -> H -> R -> a removes slot 'a'
    # User presses: Master -> H -> R -> 1
    # Result: Pairing for slot '1' is removed if it existed.
    ```

### 3. `harpoon:go`

-   **Trigger:** User executes a sequence defined in `config.yaml` ending with a specific `slot key` node that contains `{ type: "harpoon:go" }`.
-   **Behavior:**
    -   Identifies the final `slot key` of the sequence.
    -   Checks if a pairing exists for that `slot key`.
    -   If a pairing exists:
        -   Retrieves the bundle identifier associated with the `slot key`.
        -   Checks if the application with that bundle identifier is running.
        -   If not running, attempts to launch the application.
        -   If running or after successful launch, activates the application (brings it to the front).
-   **Feedback:**
    -   If no pairing exists: Displays a temporary notification (e.g., "Harpoon: No pairing found for slot 'X'").
    -   No explicit success notification needed, the application appearing is the feedback. Potential error notification if launching/activating fails.
-   **Configuration Example:**
    ```yaml
    bindings:
      h: # Master -> H
        g: # Master -> H -> G (Go mode)
          "1": { type: "harpoon:go" } # Master -> H -> G -> 1 goes to slot '1'
          a: { type: "harpoon:go" } # Master -> H -> G -> a goes to slot 'a'
    # User presses: Master -> H -> G -> 1
    # Result: Application paired with '1' (e.g., Safari) is launched/activated.
    ```

### 4. `harpoon:reset`

-   **Trigger:** User executes a sequence defined in `config.yaml` with `type: "harpoon:reset"`.
-   **Behavior:**
    -   Removes *all* existing harpoon pairings from memory and storage.
-   **Feedback:** Displays a temporary notification confirming the reset (e.g., "Harpoon: All pairings reset.").
-   **Configuration Example:**
    ```yaml
    bindings:
      h: # Master -> H
        d: # Master -> H -> D (Delete all)
          { type: "harpoon:reset" }
    # User presses: Master -> H -> D
    # Result: All pairings are cleared.
    ```

## Persistence

-   Harpoon pairings MUST persist across HyprCuts restarts.
-   Pairings SHOULD be stored in a dedicated file (e.g., `~/.config/hyprcuts/harpoon_state.json` or similar user-specific location).
-   The format SHOULD store key-value pairs, where the key is the `slot key` (as a string) and the value is the application's bundle identifier (as a string).
    ```json
    // Example harpoon_state.json
    {
      "1": "com.apple.Safari",
      "c": "com.googlecode.iterm2",
      "f": "com.figma.Desktop"
    }
    ```
-   The application MUST load existing pairings on startup and save pairings whenever they are modified (`set`, `rm`, `reset`).

## Menu Bar Integration

-   The main application menu (accessed via the status bar icon) MUST include a section displaying the current harpoon pairings.
-   This section SHOULD be dynamically updated whenever pairings change.
-   Each listed pairing SHOULD show the `slot key` and the name of the paired application (obtained from the bundle identifier if possible, otherwise show the bundle ID).
-   Example Menu Structure Addition:
    ```
    --- Separator ---
    Harpoon Pairings:
      Slot '1': Safari
      Slot 'c': iTerm2
      Slot 'f': Figma
    --- Separator ---
    Quit HyprCuts
    ```
-   If no pairings exist, the menu should indicate this (e.g., "Harpoon Pairings: (None)").

## Feedback Mechanism

-   Feedback notifications (confirmations, errors) SHOULD use the same visual mechanism currently used for displaying sequence progress (if `show_sequence_notification` is true).

## Error Handling

-   Gracefully handle cases where the frontmost application cannot be determined or its bundle identifier cannot be retrieved during `harpoon:set`. Provide user feedback.
-   Gracefully handle cases where a paired application cannot be launched or activated during `harpoon:go`. Provide user feedback.
-   Handle potential file I/O errors when loading/saving the persistence file. 
