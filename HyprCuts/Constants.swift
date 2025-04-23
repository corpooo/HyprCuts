//
//  Constants.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import Carbon.HIToolbox  // For kVK_ constants
import CoreGraphics  // For CGKeyCode, CGEventFlags
import Foundation

// Define the type alias for parsed key combos
typealias ParsedKey = (keyCode: CGKeyCode, modifiers: CGEventFlags)

struct KeyMapping {

    // Maps config string representation to CGKeyCode (for non-modifier keys)
    static let stringToKeyCodeMap: [String: CGKeyCode] = [
        // Letters (Lowercase)
        "a": CGKeyCode(kVK_ANSI_A), "b": CGKeyCode(kVK_ANSI_B), "c": CGKeyCode(kVK_ANSI_C),
        "d": CGKeyCode(kVK_ANSI_D), "e": CGKeyCode(kVK_ANSI_E), "f": CGKeyCode(kVK_ANSI_F),
        "g": CGKeyCode(kVK_ANSI_G), "h": CGKeyCode(kVK_ANSI_H), "i": CGKeyCode(kVK_ANSI_I),
        "j": CGKeyCode(kVK_ANSI_J), "k": CGKeyCode(kVK_ANSI_K), "l": CGKeyCode(kVK_ANSI_L),
        "m": CGKeyCode(kVK_ANSI_M), "n": CGKeyCode(kVK_ANSI_N), "o": CGKeyCode(kVK_ANSI_O),
        "p": CGKeyCode(kVK_ANSI_P), "q": CGKeyCode(kVK_ANSI_Q), "r": CGKeyCode(kVK_ANSI_R),
        "s": CGKeyCode(kVK_ANSI_S), "t": CGKeyCode(kVK_ANSI_T), "u": CGKeyCode(kVK_ANSI_U),
        "v": CGKeyCode(kVK_ANSI_V), "w": CGKeyCode(kVK_ANSI_W), "x": CGKeyCode(kVK_ANSI_X),
        "y": CGKeyCode(kVK_ANSI_Y), "z": CGKeyCode(kVK_ANSI_Z),

        // Numbers (Top Row)
        "0": CGKeyCode(kVK_ANSI_0), "1": CGKeyCode(kVK_ANSI_1), "2": CGKeyCode(kVK_ANSI_2),
        "3": CGKeyCode(kVK_ANSI_3), "4": CGKeyCode(kVK_ANSI_4), "5": CGKeyCode(kVK_ANSI_5),
        "6": CGKeyCode(kVK_ANSI_6), "7": CGKeyCode(kVK_ANSI_7), "8": CGKeyCode(kVK_ANSI_8),
        "9": CGKeyCode(kVK_ANSI_9),

        // Symbols (Common)
        "space": CGKeyCode(kVK_Space), "spc": CGKeyCode(kVK_Space),
        "period": CGKeyCode(kVK_ANSI_Period), ".": CGKeyCode(kVK_ANSI_Period),
        "dot": CGKeyCode(kVK_ANSI_Period),
        "comma": CGKeyCode(kVK_ANSI_Comma), ",": CGKeyCode(kVK_ANSI_Comma),
        "comm": CGKeyCode(kVK_ANSI_Comma),
        "slash": CGKeyCode(kVK_ANSI_Slash), "/": CGKeyCode(kVK_ANSI_Slash),
        "slas": CGKeyCode(kVK_ANSI_Slash),
        "backslash": CGKeyCode(kVK_ANSI_Backslash), "\\": CGKeyCode(kVK_ANSI_Backslash),
        "bsls": CGKeyCode(kVK_ANSI_Backslash),
        "semicolon": CGKeyCode(kVK_ANSI_Semicolon), ";": CGKeyCode(kVK_ANSI_Semicolon),
        "scln": CGKeyCode(kVK_ANSI_Semicolon),
        "quote": CGKeyCode(kVK_ANSI_Quote), "'": CGKeyCode(kVK_ANSI_Quote),
        "quot": CGKeyCode(kVK_ANSI_Quote),
        "leftbracket": CGKeyCode(kVK_ANSI_LeftBracket), "[": CGKeyCode(kVK_ANSI_LeftBracket),
        "lbrc": CGKeyCode(kVK_ANSI_LeftBracket),
        "rightbracket": CGKeyCode(kVK_ANSI_RightBracket), "]": CGKeyCode(kVK_ANSI_RightBracket),
        "rbrc": CGKeyCode(kVK_ANSI_RightBracket),
        "grave": CGKeyCode(kVK_ANSI_Grave), "`": CGKeyCode(kVK_ANSI_Grave),
        "grv": CGKeyCode(kVK_ANSI_Grave),
        "minus": CGKeyCode(kVK_ANSI_Minus), "-": CGKeyCode(kVK_ANSI_Minus),
        "mins": CGKeyCode(kVK_ANSI_Minus),
        "equal": CGKeyCode(kVK_ANSI_Equal), "=": CGKeyCode(kVK_ANSI_Equal),
        "eql": CGKeyCode(kVK_ANSI_Equal),

        // Special Keys
        "return": CGKeyCode(kVK_Return), "enter": CGKeyCode(kVK_Return),
        "ret": CGKeyCode(kVK_Return),
        "numpadenter": CGKeyCode(kVK_ANSI_KeypadEnter), "kpenter": CGKeyCode(kVK_ANSI_KeypadEnter),
        "tab": CGKeyCode(kVK_Tab),
        "escape": CGKeyCode(kVK_Escape), "esc": CGKeyCode(kVK_Escape),
        "delete": CGKeyCode(kVK_Delete), "backspace": CGKeyCode(kVK_Delete),
        "bspc": CGKeyCode(kVK_Delete),
        "forwarddelete": CGKeyCode(kVK_ForwardDelete), "del": CGKeyCode(kVK_ForwardDelete),
        "help": CGKeyCode(kVK_Help), "insert": CGKeyCode(kVK_Help),  // macOS Help key often acts as Insert
        "home": CGKeyCode(kVK_Home),
        "end": CGKeyCode(kVK_End),
        "pageup": CGKeyCode(kVK_PageUp), "pgup": CGKeyCode(kVK_PageUp),
        "pagedown": CGKeyCode(kVK_PageDown), "pgdn": CGKeyCode(kVK_PageDown),

        // Arrow Keys
        "left": CGKeyCode(kVK_LeftArrow), "right": CGKeyCode(kVK_RightArrow),
        "up": CGKeyCode(kVK_UpArrow), "down": CGKeyCode(kVK_DownArrow),

        // Function Keys
        "f1": CGKeyCode(kVK_F1), "f2": CGKeyCode(kVK_F2), "f3": CGKeyCode(kVK_F3),
        "f4": CGKeyCode(kVK_F4), "f5": CGKeyCode(kVK_F5), "f6": CGKeyCode(kVK_F6),
        "f7": CGKeyCode(kVK_F7), "f8": CGKeyCode(kVK_F8), "f9": CGKeyCode(kVK_F9),
        "f10": CGKeyCode(kVK_F10), "f11": CGKeyCode(kVK_F11), "f12": CGKeyCode(kVK_F12),
        "f13": CGKeyCode(kVK_F13), "f14": CGKeyCode(kVK_F14), "f15": CGKeyCode(kVK_F15),
        "f16": CGKeyCode(kVK_F16), "f17": CGKeyCode(kVK_F17), "f18": CGKeyCode(kVK_F18),
        "f19": CGKeyCode(kVK_F19), "f20": CGKeyCode(kVK_F20),

        // Specific Modifier Keys (for use as primary key, e.g., master_key)
        // Note: Generic modifiers ("cmd", "shift", etc.) are handled by flags map.
        "lcmd": CGKeyCode(kVK_Command), "rcmd": CGKeyCode(kVK_RightCommand),
        "lshift": CGKeyCode(kVK_Shift), "rshift": CGKeyCode(kVK_RightShift),
        "lopt": CGKeyCode(kVK_Option), "ropt": CGKeyCode(kVK_RightOption),
        "lctrl": CGKeyCode(kVK_Control), "rctrl": CGKeyCode(kVK_RightControl),
        "caps": CGKeyCode(kVK_CapsLock), "capslock": CGKeyCode(kVK_CapsLock),
        "fn": CGKeyCode(kVK_Function),

        // Numpad Keys (Add if needed, less common for sequences)
        // "numpad0": CGKeyCode(kVK_ANSI_Keypad0), ...
    ]

    // Maps modifier key string representation to CGEventFlags
    // Note: Left/Right variants map to the same primary flag for simplicity initially.
    // Specific L/R handling might need CGKeyCode check if required.
    static let stringToFlagsMap: [String: CGEventFlags] = [
        "cmd": .maskCommand, "lcmd": .maskCommand, "rcmd": .maskCommand,  // kVK_Command, kVK_RightCommand
        "shift": .maskShift, "lshift": .maskShift, "rshift": .maskShift, "lsft": .maskShift,
        "rsft": .maskShift,  // kVK_Shift, kVK_RightShift
        "opt": .maskAlternate, "lopt": .maskAlternate, "ropt": .maskAlternate,  // kVK_Option, kVK_RightOption
        "ctrl": .maskControl, "lctrl": .maskControl, "rctrl": .maskControl,  // kVK_Control, kVK_RightControl
        "caps": .maskAlphaShift, "capslock": .maskAlphaShift,  // kVK_CapsLock
        "fn": .maskSecondaryFn,  // kVK_Function
    ]

    // Reverse map: CGKeyCode to a primary String representation (for display/logging)
    // We choose one primary representation (e.g., lowercase letter, full name for special keys)
    static let keyCodeToStringMap: [CGKeyCode: String] = {
        // Group strings by their keycode
        let groupedByKeyCode = Dictionary(grouping: stringToKeyCodeMap, by: { $0.value })
        // For each keycode, choose the shortest string alias as the primary representation
        return groupedByKeyCode.mapValues { entries -> String in
            // Find the entry with the shortest key (string alias)
            return entries.min(by: { $0.key.count < $1.key.count })?.key ?? "unknown"
        }
    }()

    // New map for UI display symbols/strings
    static let keyDisplayMap: [String: String] = [
        // Modifiers
        "cmd": "⌘", "lcmd": "⌘", "rcmd": "⌘", "command": "⌘",
        "shift": "⇧", "lshift": "⇧", "rshift": "⇧",
        "opt": "⌥", "lopt": "⌥", "ropt": "⌥", "option": "⌥", "alt": "⌥",
        "ctrl": "⌃", "lctrl": "⌃", "rctrl": "⌃", "control": "⌃",
        "caps": "⇪", "capslock": "⇪",
        "fn": "fn",

        // Special Keys
        "return": "↩", "enter": "↩", "kpenter": "↩",
        "tab": "⇥",
        "space": "␣", "spc": "␣",
        "escape": "esc", "esc": "esc",
        "delete": "⌫", "backspace": "⌫",
        "forwarddelete": "⌦", "del": "⌦",
        "home": "↖",
        "end": "↘",
        "pageup": "⇞", "pgup": "⇞",
        "pagedown": "⇟", "pgdn": "⇟",

        // Arrows
        "left": "←", "leftArrow": "←",
        "right": "→", "rightArrow": "→",
        "up": "↑", "upArrow": "↑",
        "down": "↓", "downArrow": "↓",

        // Symbols (can keep short versions)
        "period": ".",
        "comma": ",",
        "slash": "/",
        "backslash": "\\",
        "semicolon": ";",
        "quote": "'",
        "leftbracket": "[",
        "rightbracket": "]",
        "grave": "`",
        "minus": "-",
        "equal": "=",

            // Default to uppercase for letters if no specific symbol
            // Function Keys (F1, F2...)
            // Numbers (0-9)
            // We can rely on the default uppercasing logic in the View for these
    ]

    // Helper to get KeyCode from string
    static func getKeyCode(for string: String) -> CGKeyCode? {
        return stringToKeyCodeMap[string.lowercased()]  // Use lowercase for case-insensitivity
    }

    // Helper to get Flags from string
    static func getFlags(for string: String) -> CGEventFlags? {
        return stringToFlagsMap[string.lowercased()]  // Use lowercase for case-insensitivity
    }

    // Helper to get primary String representation from KeyCode
    static func getString(for keyCode: CGKeyCode) -> String? {
        // Prioritize the direct reverse mapping
        if let primaryString = keyCodeToStringMap[keyCode] {
            // Handle cases where multiple strings map to the same keycode - return the shortest/most common?
            // For now, just return the one found in the reversed map.
            // We might need a more curated map if this isn't sufficient.
            return primaryString
        }
        // Add specific fallbacks if needed, though the map should cover most keys defined above.
        return nil
    }

    // Helper to get display string (symbol or formatted key name)
    static func getDisplayString(for keyString: String) -> String {
        let lowercasedKey = keyString.lowercased()
        // Check the explicit display map first
        if let symbol = keyDisplayMap[lowercasedKey] {
            return symbol
        }
        // If not found, return the original string, perhaps capitalized nicely
        // (e.g., ensure F-keys are uppercase)
        if lowercasedKey.starts(with: "f") && Int(lowercasedKey.dropFirst()) != nil {
            return lowercasedKey.uppercased()  // F1, F2...
        }
        // Default to uppercasing letters, leave others as is
        if lowercasedKey.count == 1 && lowercasedKey >= "a" && lowercasedKey <= "z" {
            return lowercasedKey.uppercased()
        }
        // Return original if no specific rule applies
        return keyString
    }

    // Parses a key binding string (e.g., "cmd+shift+k", "f", "lctrl+return")
    // into its non-modifier key code and the combined modifier flags.
    // Returns nil if the string is invalid (e.g., multiple non-modifier keys, unknown keys).
    static func parseBindingKeyCombo(keyString: String) -> ParsedKey? {
        let parts = keyString.lowercased().split(separator: "+").map(String.init)

        var keyCode: CGKeyCode? = nil
        var modifiers: CGEventFlags = []
        var foundNonModifierKey = false

        for part in parts {
            if let flags = getFlags(for: part) {
                // It's a modifier
                modifiers.insert(flags)
            } else if let code = getKeyCode(for: part) {
                // It's potentially a non-modifier key OR a specific modifier key like 'lcmd' used as the main key
                // Check if it's a specific modifier key code that ALSO has flags defined
                let isSpecificModifierKeyCode = stringToFlagsMap.keys.contains(part)

                if !isSpecificModifierKeyCode {
                    // This is a standard non-modifier key (a, b, 1, enter, f1, etc.)
                    if foundNonModifierKey {
                        // Invalid: multiple non-modifier keys found (e.g., "a+b")
                        // Logger.log("Error parsing key combo '\(keyString)': Multiple non-modifier keys found.")
                        return nil
                    }
                    keyCode = code
                    foundNonModifierKey = true
                } else {
                    // This is a specific modifier key allowed as the *primary* key in a combo
                    // e.g. "shift+lcmd" where lcmd is the target key.
                    // Or it could be ONLY a specific modifier e.g. "lcmd"
                    if foundNonModifierKey {
                        // Invalid: A non-modifier key was already found, cannot add a specific modifier as another primary key.
                        // Logger.log("Error parsing key combo '\(keyString)': Found specific modifier '\(part)' after non-modifier key.")
                        return nil
                    }
                    // If this is the *only* key, treat it as the keyCode
                    if parts.count == 1 {
                        keyCode = code
                        foundNonModifierKey = true  // Treat single specific modifier as the 'non-modifier' part for parsing result
                    } else {
                        // If part of a combo (e.g., "shift+lcmd"), we already added its flag.
                        // We need to decide if this specific modifier should be the keyCode.
                        // Let's assume the *last* specific key encountered is the target if no other non-modifier is found.
                        // This allows combos like "shift+capslock" where capslock is the key.
                        keyCode = code  // Tentatively set it, might be overwritten by a later *actual* non-modifier
                    }
                }
            } else {
                // Unknown key part
                // Logger.log("Error parsing key combo '\(keyString)': Unknown key part '\(part)'.")
                return nil
            }
        }

        // Must have exactly one effective non-modifier key code
        if let finalKeyCode = keyCode, foundNonModifierKey || parts.count == 1 {
            // Special case: if the final key code itself represents a modifier (like kVK_Command for lcmd),
            // ensure its corresponding flag isn't *also* set from the modifier part, unless intended.
            // Example: "lcmd" -> keyCode=kVK_Command, modifiers=[].
            // Example: "shift+lcmd" -> keyCode=kVK_Command, modifiers=[.maskShift].
            // This seems correct as is.
            return (keyCode: finalKeyCode, modifiers: modifiers)
        } else {
            // Invalid: No non-modifier key found (e.g., "cmd+shift") or logic error
            // Logger.log("Error parsing key combo '\(keyString)': No valid non-modifier key found.")
            return nil
        }
    }

    // TODO: Need a function to convert a config string into *either* a KeyCode or Flags,
    //       as the master key could be either type. --> This seems resolved by using getKeyCode and validation elsewhere.
}
