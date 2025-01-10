//
//  KeyboardManager.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/10.
//

import Foundation
import CoreGraphics

class KeyboardManager {
    static let shared = KeyboardManager()
    
    private let modifierKeywords: [String: CGEventFlags] = [
        "command": .maskCommand,
        "cmd": .maskCommand,
        "option": .maskAlternate,
        "opt": .maskAlternate,
        "control": .maskControl,
        "ctrl": .maskControl,
        "shift": .maskShift,
        "numpad": .maskNumericPad
    ]
    
    private let specialKeys: [String: CGKeyCode] = [
        "return": 0x24,
        "space": 0x31,
        "delete": 0x33,
        "escape": 0x35,
        "left": 0x7B,
        "right": 0x7C,
        "down": 0x7D,
        "up": 0x7E,
        "f1": 0x7A,
        "f2": 0x78,
        "f3": 0x63,
        "f4": 0x76,
        "f5": 0x60,
        "f6": 0x61,
        "f7": 0x62,
        "f8": 0x64,
        "f9": 0x65,
        "f10": 0x6D,
        "f11": 0x67,
        "f12": 0x6F,
        "f13": 0x69,
        "f14": 0x6B,
        "f15": 0x71,
        "f16": 0x6A,
        "f17": 0x40,
        "f18": 0x4F,
        "f19": 0x50,
        "f20": 0x5A
    ]
    
    func simulateKeyPress(from command: String) {
        let components = command.lowercased().components(separatedBy: .whitespaces)
        var modifiers: CGEventFlags = []
        var key: String = ""
        
        for component in components {
            if let modifier = modifierKeywords[component] {
                modifiers.insert(modifier)
            } else {
                key = component
            }
        }
        
        var keyCode: CGKeyCode = 0
        if key.hasPrefix("0x") {
            if let code = Int(key.dropFirst(2), radix: 16) {
                keyCode = CGKeyCode(code)
            }
        } else if let specialKeyCode = specialKeys[key] {
            keyCode = specialKeyCode
        } else if key.count == 1 {
            // 映射普通字符到虚拟键码
            let character = key.unicodeScalars.first!
            if let keyCodeValue = charToKeyCode(character) {
                keyCode = keyCodeValue
            }
        }
        
        if let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            event.flags = modifiers
            event.post(tap: .cghidEventTap)
            
            // 模拟按键释放
            let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            eventUp?.flags = modifiers
            eventUp?.post(tap: .cghidEventTap)
        }
    }
    
    private func charToKeyCode(_ char: UnicodeScalar) -> CGKeyCode? {
        let lowerChar = String(char).lowercased().unicodeScalars.first!
        switch lowerChar {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'": return 0x27
        case "k": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".": return 0x2F
        case "`": return 0x32
        case " ": return 0x31
        default: return nil
        }
    }
}
