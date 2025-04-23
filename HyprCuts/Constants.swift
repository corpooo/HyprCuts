//
//  Constants.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 17.04.2025.
//

import Foundation
import Carbon.HIToolbox // For kVK_ constants
import CoreGraphics     // For CGKeyCode, CGEventFlags

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
        "period": CGKeyCode(kVK_ANSI_Period), ".": CGKeyCode(kVK_ANSI_Period), "dot": CGKeyCode(kVK_ANSI_Period),
        "comma": CGKeyCode(kVK_ANSI_Comma), ",": CGKeyCode(kVK_ANSI_Comma), "comm": CGKeyCode(kVK_ANSI_Comma),
        "slash": CGKeyCode(kVK_ANSI_Slash), "/": CGKeyCode(kVK_ANSI_Slash), "slas": CGKeyCode(kVK_ANSI_Slash),
        "backslash": CGKeyCode(kVK_ANSI_Backslash), "\\": CGKeyCode(kVK_ANSI_Backslash), "bsls": CGKeyCode(kVK_ANSI_Backslash),
        "semicolon": CGKeyCode(kVK_ANSI_Semicolon), ";": CGKeyCode(kVK_ANSI_Semicolon), "scln": CGKeyCode(kVK_ANSI_Semicolon),
        "quote": CGKeyCode(kVK_ANSI_Quote), "'": CGKeyCode(kVK_ANSI_Quote), "quot": CGKeyCode(kVK_ANSI_Quote),
        "leftbracket": CGKeyCode(kVK_ANSI_LeftBracket), "[": CGKeyCode(kVK_ANSI_LeftBracket), "lbrc": CGKeyCode(kVK_ANSI_LeftBracket),
        "rightbracket": CGKeyCode(kVK_ANSI_RightBracket), "]": CGKeyCode(kVK_ANSI_RightBracket), "rbrc": CGKeyCode(kVK_ANSI_RightBracket),
        "grave": CGKeyCode(kVK_ANSI_Grave), "`": CGKeyCode(kVK_ANSI_Grave), "grv": CGKeyCode(kVK_ANSI_Grave),
        "minus": CGKeyCode(kVK_ANSI_Minus), "-": CGKeyCode(kVK_ANSI_Minus), "mins": CGKeyCode(kVK_ANSI_Minus),
        "equal": CGKeyCode(kVK_ANSI_Equal), "=": CGKeyCode(kVK_ANSI_Equal), "eql": CGKeyCode(kVK_ANSI_Equal),

        // Special Keys
        "return": CGKeyCode(kVK_Return), "enter": CGKeyCode(kVK_Return), "ret": CGKeyCode(kVK_Return),
        "numpadenter": CGKeyCode(kVK_ANSI_KeypadEnter), "kpenter": CGKeyCode(kVK_ANSI_KeypadEnter),
        "tab": CGKeyCode(kVK_Tab),
        "escape": CGKeyCode(kVK_Escape), "esc": CGKeyCode(kVK_Escape),
        "delete": CGKeyCode(kVK_Delete), "backspace": CGKeyCode(kVK_Delete), "bspc": CGKeyCode(kVK_Delete),
        "forwarddelete": CGKeyCode(kVK_ForwardDelete), "del": CGKeyCode(kVK_ForwardDelete),
        "help": CGKeyCode(kVK_Help), "insert": CGKeyCode(kVK_Help), // macOS Help key often acts as Insert
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
        "cmd": .maskCommand, "lcmd": .maskCommand, "rcmd": .maskCommand, // kVK_Command, kVK_RightCommand
        "shift": .maskShift, "lshift": .maskShift, "rshift": .maskShift, "lsft": .maskShift, "rsft": .maskShift, // kVK_Shift, kVK_RightShift
        "opt": .maskAlternate, "lopt": .maskAlternate, "ropt": .maskAlternate, // kVK_Option, kVK_RightOption
        "ctrl": .maskControl, "lctrl": .maskControl, "rctrl": .maskControl, // kVK_Control, kVK_RightControl
        "caps": .maskAlphaShift, "capslock": .maskAlphaShift, // kVK_CapsLock
        "fn": .maskSecondaryFn, // kVK_Function
    ]

    // Helper to get KeyCode from string
    static func getKeyCode(for string: String) -> CGKeyCode? {
        return stringToKeyCodeMap[string.lowercased()] // Use lowercase for case-insensitivity
    }

    // Helper to get Flags from string
    static func getFlags(for string: String) -> CGEventFlags? {
        return stringToFlagsMap[string.lowercased()] // Use lowercase for case-insensitivity
    }

    // TODO: Need a function to convert a config string into *either* a KeyCode or Flags,
    //       as the master key could be either type.
    // TODO: Consider adding reverse mapping (KeyCode -> String) if needed for display/logging.
}
