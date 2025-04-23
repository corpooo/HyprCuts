# HyprCuts v2 - Acceptance Criteria

This document outlines the acceptance criteria for HyprCuts v2, focusing on the transition to a tree-based binding structure and updated sequence handling.

## 1. Configuration Schema v2

*   **AC1.1:** The `config.yaml` structure must support a nested tree format for key `bindings`.
    *   Keys within the `bindings` object represent the key sequence characters (e.g., `o`, `a`, `b`).
    *   Each key maps to either:
        *   An **action object** (leaf node defining an action).
        *   Another **nested bindings object** (branch node).
    *   Example structure:
        ```yaml
        master_key: "'"
        # sequence_timeout_ms: (Deprecated in v2)
        show_sequence_notification: true
        master_key_tap_timeout_ms: 200 # Retained for tap vs hold detection

        bindings:
          o: # Press 'o' after master key
            a: { type: "shell_command", command: "echo 'OA'" } # Leaf: O -> A action
            b: { type: "open_app", target: "Calculator" }     # Leaf: O -> B action
            c: # Branch node: O -> C
              d: { type: "keys", keys: ["cmd", "c"] }        # Leaf: O -> C -> D action
              e: { type: "reset" }                           # Leaf: O -> C -> E action (resets state)
          x: { type: "shell_command", command: "echo 'X'" }   # Leaf: X action
          y: {} # Leaf node with NO action defined
          z: # Branch node with NO leaf action defined
             f: { type: "shell_command", command: "echo 'ZF'" } # Leaf: Z -> F action
        ```
*   **AC1.2:** All actions MUST be defined using the object format: `{type: <action-type>, <argument-name>: <argument>, ...}`. The simple string format (`<action-type>:<action-argument>`) is deprecated and no longer supported.
*   **AC1.3:** The `sequence_timeout_ms` configuration key is deprecated and should be ignored if present.
*   **AC1.4:** Configuration parsing must correctly build an internal representation mirroring the nested tree structure. Validation should ensure keys are valid strings and action objects have at least a `type` field.
*   **AC1.5:** Introduce a new standard action type: `reset`. This action takes no arguments.

## 2. Key Sequence Processing v2

*   **AC2.1:** Key sequence processing begins when the `master_key` is held down.
*   **AC2.2:** The application maintains a "current node" state within the `bindings` tree, starting at the root when the `master_key` is initially pressed.
*   **AC2.3:** When a key (e.g., `k`) is pressed while `master_key` is held:
    *   **a)** Check if `k` exists as a child of the *current node*.
        *   If yes: Update the *current node* to the child node corresponding to `k`. Proceed to AC2.4.
    *   **b)** If no: Traverse *up* the ancestor path from the *current node* towards the root. At each ancestor level, check if `k` exists as a child of that ancestor.
        *   If yes (found at an ancestor level): Update the *current node* to the child node corresponding to `k` at that ancestor level. Proceed to AC2.4.
    *   **c)** If no (not found as a child of the current node or any ancestor): The key press is invalid for the current sequence state. Ignore the key press. Provide optional feedback (e.g., toast notification, log). The *current node* remains unchanged.
*   **AC2.4:** After updating the *current node* (based on AC2.3a or AC2.3b):
    *   **a)** Check if the *new current node* has an associated action defined (i.e., it's a leaf node with an action object, like `o -> a` or `x` in the example).
        *   If yes: Execute the action. After execution, **revert** the *current node* state back to its **parent node**. (e.g., after `master_key -> O -> A` triggers, the state becomes `master_key -> O`). If the triggered node was at the root (like `X`), the state reverts to the root.
    *   **b)** Check if the *new current node* is a leaf node with *no* action defined (like `y` in the example).
        *   If yes: Do nothing, but **revert** the *current node* state back to its **parent node**.
    *   **c)** Check if the *new current node* is a branch node (like `o -> c` or `z` in the example), regardless of whether it *also* has an action defined directly on it (which is discouraged but could technically occur).
        *   If yes: Do nothing immediately. The *current node* **remains** at this branch node, waiting for the next key press.
*   **AC2.5:** If the executed action (from AC2.4a) is of type `reset`: Reset the *current node* state to the root, as if the `master_key` had just been pressed.
*   **AC2.6:** The entire sequence state (the *current node*) is reset to the root immediately when the `master_key` is released.
*   **AC2.7:** The concept of a sequence timeout between key presses is removed. State persists as long as `master_key` is held (unless reset by release or `reset` action).

## 3. Action Execution v2

*   **AC3.1:** Action execution remains largely the same, triggered according to AC2.4a.
*   **AC3.2:** The new `reset` action type must be implemented as described in AC2.5.
*   **AC3.3:** Error handling for failed actions (e.g., `shell_command` error, `open_app` not found) should remain, providing user feedback (toast/log) as per v1 ACs.

## 4. UI/UX v2

*   **AC4.1:** Remove any UI elements or textual displays related to `sequence_timeout_ms`.
*   **AC4.2:** Update menu bar display (if it shows master key or status) to reflect v2 state logic if necessary. (Consider potential need for a "Sequence Active" indicator if master key is held).
*   **AC4.3:** Review toast notification logic (`show_sequence_notification`):
    *   It should now show the current *valid* sequence path as it's built (e.g., "O", then "O > C").
    *   Feedback for invalid keys (AC2.3c) should be provided if notifications are enabled.

## 5. Deprecation & Cleanup

*   **AC5.1:** Remove code related to `sequence_timeout_ms` handling.
*   **AC5.2:** Remove code related to parsing the old string-based action format.
*   **AC5.3:** Update documentation (README, comments) to reflect the v2 configuration schema and behavior. 
