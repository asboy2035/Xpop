//
//  TextSelection.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import ApplicationServices
import Cocoa
import Combine
import SwiftUI
import Foundation
import AppKit

// MARK: - Error Handling
/// Enum for text selection errors with user-friendly descriptions.
enum TextSelectionError: Error {
    // Accessibility & 权限问题
    case accessibilityPermissionDenied
    case scriptingPermissionDenied // 没有执行 AppleScript 的权限

    // 元素与内容问题
    case noFocusedElement
    case noTextFound
    case emptyText
    case unsupportedType(type: Any.Type) // 未知值类型错误
    case failedToRetrieveAttribute(String)

    // AppleScript 特定错误
    case scriptSyntaxError(String) // AppleScript 语法错误
    case runtimeError(code: Int, message: String) // AppleScript 运行时错误
    case unknownAppleScriptError // AppleScript 未知错误
    case unsupportedCommand(String) // AppleScript 不支持的命令

    // 范围和标记错误
    case AXSelectedTextMarkerRange
    case AXStringForTextMarkerRange
    case invalidMarkerRangeType(type: Any.Type)
    case unsupportedMarkerRange

    // 通用错误
    case genericError(message: String) // 通用的未知错误
    
    /// 错误描述方法
    func description() -> String {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied. Please enable it in System Preferences."
        case .scriptingPermissionDenied:
            return "AppleScript execution permission denied. Please enable scripting permissions in System Preferences."
        case .noFocusedElement:
            return "Unable to find a focused element to retrieve text."
        case .noTextFound:
            return "No text found in the selected area."
        case .emptyText:
            return "Selected text is empty."
        case .unsupportedType(let type):
            return "Unsupported value type encountered: \(type)."
        case .failedToRetrieveAttribute(let attribute):
            return "Failed to retrieve attribute: \(attribute)."
        case .scriptSyntaxError(let message):
            return "AppleScript syntax error: \(message)."
        case .runtimeError(let code, let message):
            return "AppleScript runtime error (\(code)): \(message)."
        case .unknownAppleScriptError:
            return "An unknown AppleScript error occurred."
        case .unsupportedCommand(let command):
            return "AppleScript unsupported command: \(command)."
        case .AXSelectedTextMarkerRange:
            return "Unable to get AXSelectedTextMarkerRange."
        case .AXStringForTextMarkerRange:
            return "Unable to get AXStringForTextMarkerRange."
        case .invalidMarkerRangeType(let type):
            return "Invalid AXSelectedTextMarkerRange type: \(type)."
        case .unsupportedMarkerRange:
            return "AXStringForTextMarkerRange returned an unsupported range."
        case .genericError(let message):
            return "An error occurred: \(message)"
        }
    }
}

// 定义可能的错误类型
enum CopyMenuError: Error {
    case menuBarNotFound
    case childrenNotFound
    case menuItemNotFound
    case menuItemNotEnabled
    case actionFailed
    case clipboardNotUpdated
}


// MARK: - Text Selection Manager

/// Manages the text selection process.
public class TextSelectionManager: ObservableObject {
    @State private var stateManager = MenuActionStateManager.shared
    @Published public var selectedText: String? = "" {
        didSet {
            // 当 selectedText 发生变化时，写入环境变量
            if let selectedText = selectedText {
                setEnvironmentVariable("POPCLIP_TEXT", value: selectedText)
                setEnvironmentVariable("XPOP_TEXT", value: selectedText)
            } else {
                // 如果 selectedText 为 nil，清空环境变量
                setEnvironmentVariable("POPCLIP_TEXT", value: "")
                setEnvironmentVariable("XPOP_TEXT", value: "")
            }
        }
    }

    @Published var currentApp: String = ""
    @Published var selectionMethod: String = ""

    private var lastCheckTime: Date = Date()
    public var lastSelectedText: String?
    private let logger = Logger.shared

    public init() {
    }
    
    /// 设置环境变量的辅助方法
    private func setEnvironmentVariable(_ name: String, value: String) {
        setenv(name, value, 1) // 1 表示覆盖已存在的环境变量
        logger.log("Environment variable %{public}@ set to: %{public}@", name, value, type: .debug)
    }
    

    /// 读取环境变量的辅助方法
    private func getEnvironmentVariable(_ name: String) -> String? {
        guard let value = getenv(name) else {
            logger.log("Environment variable %{public}@ not found", name, type: .debug)
            return nil
        }
        let stringValue = String(cString: value)
        logger.log("Environment variable %{public}@ read: %{public}@", name, stringValue, type: .debug)
        return stringValue
    }

    
    public func getSelectedText() async throws -> String {
        // 1. check accessibility permission
        guard AXIsProcessTrusted() else {
            throw TextSelectionError.accessibilityPermissionDenied
        }
        // 2. get frontmost application
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            throw TextSelectionError.noFocusedElement
        }
        // 3. get app reference
        let appRef = AXUIElementCreateApplication(activeApp.processIdentifier)
        // 4. get focused element
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(
            appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let focusedElement = focusedElement else {
            throw TextSelectionError.noFocusedElement
        }
        
        // Extract properties of `activeApp`
        let appName = activeApp.localizedName ?? "Unknown App"
        // Update `currentApp` on the main thread
        await MainActor.run {
            self.currentApp = appName
        }

        // 5. 尝试依次使用三种方法获取文本
        // 定义一个包含方法名称和方法的元组类型
        typealias TextFetchMethod = (name: String, method: (AXUIElement) async throws -> String)
        var methods: [TextFetchMethod] = [
            (name: "getTextFromSelectedAttribute", method: getTextFromSelectedAttribute),
            (name: "getTextFromTextMarker", method: getTextFromTextMarker)
        ]

        let enableForce: Bool = UserDefaults.standard.bool(forKey: "enableForceCopy")
        // 如果 enableForce 为 true，添加第三种方法
        if enableForce {
            methods.append((name: "getTextFromMenubar", method: { _ in try await self.getTextFromMenubar(for: appRef) }))
        }
        await stateManager.updateStates(for: appRef)
        for method in methods {
            do {
                self.selectedText = try await method.method(focusedElement as! AXUIElement)
                logger.log("SelectText Method: %{public}@", method.name, type: .info)
                return self.selectedText ?? ""
            } catch {
                // 如果当前方法失败，则继续尝试下一个方法
                continue
            }
        }
        
        // 如果所有方法都失败，抛出特定错误
        throw TextSelectionError.noTextFound
    }
    
    private func getTextFromMenubar(for element: AXUIElement) async throws -> String {
        let finder = MenuActionFinder()
        let clipboardManager = ClipboardManager()
        // 查找复制菜单项
        let copyItem = try await finder.findMenuItem(in: element, action: "Copy")
        // 创建点击复制菜单项的闭包
        let action = finder.createClickMenuItemAction(for: copyItem, action: "Copy")
        
        // 直接调用 performClipboardAction，将错误完全向上传递
        guard let result = try await clipboardManager.performClipboardAction(action: action, delay: 0.05) else {
            throw TextSelectionError.genericError(message: "Failed to retrieve text from clipboard.")
        }
        return result
    }
    
    private func getTextFromSelectedAttribute(for element: AXUIElement) async throws -> String {
        var value: AnyObject?
        
        // 尝试获取 `kAXSelectedTextAttribute`
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success {
            // 检查是否为 String 类型
            if let text = value as? String {
                return text
            }
            // 检查是否为 NSAttributedString 类型
            if let attributedText = value as? NSAttributedString {
                return attributedText.string // 转换为普通文本
            }
            // 如果为未知类型，抛出错误
            throw TextSelectionError.unsupportedType(type: type(of: value))
        } else {
            // 获取失败时抛出特定错误
            throw TextSelectionError.noTextFound
        }
    }

    private func getTextFromTextMarker(for element: AXUIElement) async throws -> String {
        var markerValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &markerValue)
        
        // 确保 markerRange 存在
        guard result == .success, let markerRange = markerValue else {
            throw TextSelectionError.AXSelectedTextMarkerRange
        }
        
        var selectedText: AnyObject?
        
        // 获取 `AXStringForTextMarkerRange` 的值
        if AXUIElementCopyParameterizedAttributeValue(
            element, "AXStringForTextMarkerRange" as CFString, markerRange, &selectedText) == .success {
            
            // 检查是否为 String 类型
            if let text = selectedText as? String {
                return text
            }
            throw TextSelectionError.AXStringForTextMarkerRange
        } else {
            // 如果访问失败，则抛出错误
            throw TextSelectionError.AXStringForTextMarkerRange
        }
    }

    private func getTextFromAppleScript(script: String) -> Result<String, TextSelectionError> {
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        if let result = appleScript?.executeAndReturnError(&errorDict) {
            // 检查返回值是否为 String
            if let text = result.stringValue {
                return .success(text)
            } else {
                return .failure(.unsupportedType(type: type(of: result)))
            }
        } else {
            // 如果 AppleScript 执行失败，解析错误信息
            if let errorInfo = errorDict,
               let errorCode = errorInfo["NSAppleScriptErrorNumber"] as? Int,
               let errorMessage = errorInfo["NSAppleScriptErrorMessage"] as? String {
                switch errorCode {
                case -1713: // Accessibility 权限被拒绝
                    return .failure(.accessibilityPermissionDenied)
                case -1719: // AppleScript 脚本执行失败
                    return .failure(.runtimeError(code: errorCode, message: errorMessage))
                default:
                    return .failure(.genericError(message: errorMessage))
                }
            } else {
                return .failure(.unknownAppleScriptError)
            }
        }
    }
    
    private func getSafariSelectedText() -> Result<String, TextSelectionError> {
        let script = ApplicationAppleScripts.getSelectedTextFromSafari
        return getTextFromAppleScript(script: script)
    }

    /// Updates the selected text if it has changed.
    @MainActor
    private func updateSelectedText(_ text: String, method: String) {
        if text != lastSelectedText {
            selectedText = text
            selectionMethod = method
            lastSelectedText = text
        }
    }
}

class AppleScriptRunner {
    /// 异步执行 AppleScript 脚本
    /// - Parameters:
    ///   - script: 要执行的 AppleScript 字符串
    ///   - completion: 异步回调，返回执行结果或错误
    func run(script: String, completion: @escaping (Result<String, TextSelectionError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?

            guard let result = appleScript?.executeAndReturnError(&errorDict) else {
                if let errorInfo = errorDict,
                   let errorCode = errorInfo["NSAppleScriptErrorNumber"] as? Int {
                    let error = self.mapAppleScriptError(code: errorCode, description: errorInfo["NSAppleScriptErrorMessage"] as? String)
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.unknownAppleScriptError))
                    }
                }
                return
            }

            let output = result.stringValue ?? ""
            DispatchQueue.main.async {
                if output.isEmpty {
                    completion(.failure(.emptyText))
                } else {
                    completion(.success(output))
                }
            }
        }
    }

    /// 将 AppleScript 错误代码映射到 TextSelectionError
    /// - Parameters:
    ///   - code: AppleScript 错误代码
    ///   - description: AppleScript 错误描述
    /// - Returns: 映射的 TextSelectionError
    private func mapAppleScriptError(code: Int, description: String?) -> TextSelectionError {
        switch code {
        case -1713:
            return .accessibilityPermissionDenied
        case -1719:
            return .scriptingPermissionDenied
        case -1004:
            return .unsupportedCommand(description ?? "Unknown command")
        case -2740:
            return .scriptSyntaxError(description ?? "Syntax error in the script")
        case -1708:
            return .runtimeError(code: code, message: description ?? "Unsupported operation")
        default:
            if let message = description {
                return .runtimeError(code: code, message: message)
            } else {
                return .unknownAppleScriptError
            }
        }
    }
}

class ApplicationAppleScripts {
    /// 获取 Safari 中选中文本的脚本
    static var getSelectedTextFromSafari: String {
        return """
        tell application "Safari"
            -- Get the current tab's selected text using JavaScript
            set selectedText to do JavaScript "window.getSelection().toString();" in current tab of front window
        end tell
        """
    }

    /// 获取 Chrome 中选中文本的脚本
    static var getSelectedTextFromChrome: String {
        return """
        tell application "Google Chrome"
            execute front window's active tab javascript "window.getSelection().toString();"
        end tell
        """
    }

    /// 获取当前时间的通用脚本（示例）
    static var getCurrentTime: String {
        return """
        set current_time to (current date) as string
        return current_time
        """
    }

    /// 设置剪贴板内容的脚本
    static func setClipboardText(_ text: String) -> String {
        return """
        set the clipboard to "\(text)"
        """
    }

    /// 模板化的脚本：根据输入生成脚本
    /// - Parameter appId: 应用的 Bundle ID
    /// - Parameter javascript: JavaScript 字符串
    /// - Returns: AppleScript 字符串
    static func getSelectedTextScript(forAppWithId appId: String, javascript: String) -> String {
        return """
        tell application id "\(appId)"
            tell front window
                set selection_text to do JavaScript "\(javascript)" in current tab
            end tell
        end tell
        """
    }
}

class ClipboardManager {
    private var backupItems: [NSPasteboardItem] = []
    private var wasClipboardEmpty: Bool = false
    private let logger = Logger.shared

    /// 保存当前剪贴板内容（深拷贝）
    func saveClipboardContents() throws {
        let pasteboard = NSPasteboard.general
        backupItems = []

        guard let items = pasteboard.pasteboardItems else {
            throw TextSelectionError.genericError(message: "Failed to access clipboard items.")
        }

        if items.isEmpty {
            wasClipboardEmpty = true
            return // 正常情况：剪贴板为空
        }

        wasClipboardEmpty = false
        for item in items {
            let backupItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    backupItem.setData(data, forType: type)
                } else {
                    throw TextSelectionError.failedToRetrieveAttribute("Failed to copy data for type: \(type.rawValue).")
                }
            }
            backupItems.append(backupItem)
        }
    }

    /// 恢复剪贴板内容
    func restoreClipboardContents() throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

//        if wasClipboardEmpty {
//            return // 如果原本剪贴板为空，则保持空状态
//        }

        for item in backupItems {
            guard pasteboard.writeObjects([item]) else {
                throw TextSelectionError.genericError(message: "Failed to restore clipboard contents.")
            }
        }
    }

    /// 执行操作并恢复剪贴板，返回操作的结果
    /// - Parameters:
    ///   - action: 回调函数，用于模拟剪贴板操作（如 Command + C）
    ///   - delay: 延迟恢复时间，单位为秒
    /// - Returns: 剪贴板上的字符串内容
    func performClipboardAction(action: ()async throws -> String?, delay: TimeInterval = 0.1) async throws -> String? {
        do {
            try saveClipboardContents() // 保存原始内容
            let result = try await action() // 执行操作，例如模拟 Command + C
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) // 延迟恢复
            try restoreClipboardContents() // 恢复原始内容
            return result
        } catch let error as TextSelectionError {
            logger.log("Error during clipboard operation: %{public}@", error.description(), type: .error)
            throw error
        } catch {
            logger.log("Unknown error: %{public}@", error.localizedDescription, type: .error)
            throw TextSelectionError.genericError(message: "Unknown error during clipboard operation.")
        }
    }
}

class MenuActionStateManager: ObservableObject {
    static let shared = MenuActionStateManager()
    
    @Published var canCopy: Bool = false
    @Published var canCut: Bool = false
    @Published var canPaste: Bool = false
    
    private init() {}

    @MainActor
    func updateStates(for element: AXUIElement) async {
        let menuFinder = MenuActionFinder()
        
        // 检查 Copy 是否可用
        do {
            let _ = try await menuFinder.findMenuItem(in: element, action: "Copy")
            canCopy = true
        } catch {
            print(error.localizedDescription)
            canCopy = false
        }
        
        // 检查 Cut 是否可用
        do {
            let _ = try await menuFinder.findMenuItem(in: element, action: "Cut")
            canCut = true
        } catch {
            canCut = false
        }
        
        // 检查 Paste 是否可用
        do {
            let _ = try await menuFinder.findMenuItem(in: element, action: "Paste")
            canPaste = true
        } catch {
            canPaste = false
        }
    }
}

class MenuActionFinder {
    private let actionTitles: [String: Set<String>] = [
        "Copy": [
            "Copy",  // English
            "拷贝", "复制",  // Simplified Chinese
            "拷貝", "複製",  // Traditional Chinese
            "コピー",  // Japanese
            "복사",  // Korean
            "Copier",  // French
            "Copiar",  // Spanish, Portuguese
            "Copia",  // Italian
            "Kopieren",  // German
            "Копировать",  // Russian
        ],
        "Cut": [
            "Cut",  // English
            "剪切",  // Simplified Chinese
            "剪下",  // Traditional Chinese
            "カット",  // Japanese
            "자르기",  // Korean
            "Couper",  // French
            "Cortar",  // Spanish, Portuguese
            "Taglia",  // Italian
            "Ausschneiden",  // German
            "Вырезать",  // Russian
        ],
        "Paste": [
            "Paste",  // English
            "粘贴",  // Simplified Chinese
            "貼上",  // Traditional Chinese
            "ペースト",  // Japanese
            "붙여넣기",  // Korean
            "Coller",  // French
            "Pegar",  // Spanish, Portuguese
            "Incolla",  // Italian
            "Einfügen",  // German
            "Вставить",  // Russian
        ]
    ]

    /// 查找指定 AXUIElement 中的可用菜单项（Copy, Cut, Paste）
    func findMenuItem(in element: AXUIElement, action: String) async throws -> AXUIElement {
        guard let titles = actionTitles[action] else {
            throw MenuActionError.invalidAction
        }
        guard let menuItem = try await findMenuItemRecursively(in: element, titles: titles) else {
            throw MenuActionError.menuItemNotFound
        }
        if !isMenuItemEnabled(menuItem) {
            
            throw MenuActionError.menuItemNotEnabled
        }
        return menuItem
    }
    
    /// 创建一个闭包，用于点击指定的菜单项并返回剪贴板内容（仅适用于 Copy 和 Cut）
    func createClickMenuItemAction(for menuItem: AXUIElement, action: String) -> () async throws -> String? {
        return {
            let pasteboard = NSPasteboard.general
            let initialChangeCount = pasteboard.changeCount
            
            // 执行点击动作
            let result = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
            if result != .success {
                throw MenuActionError.actionFailed
            }
            // 等待剪贴板更新
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            _ = pasteboard.changeCount
            
            // 检查剪贴板是否更新（仅适用于 Copy 和 Cut）
            if action == "Copy" || action == "Cut" {
                if pasteboard.changeCount != initialChangeCount {
                    return pasteboard.string(forType: .string)
                } else {
                    throw MenuActionError.clipboardNotUpdated
                }
            } else {
                return nil
            }
        }
    }

    // MARK: - Private Helper Methods

    private func findMenuItemRecursively(in element: AXUIElement, titles: Set<String>) async throws -> AXUIElement? {
        var menuBar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMenuBarAttribute as CFString, &menuBar) == .success else {
            throw MenuActionError.menuBarNotFound
        }
        let menuBarElement = menuBar as! AXUIElement
        return try await searchMenuItemRecursively(menuBarElement, titles: titles)
    }

    private func searchMenuItemRecursively(_ element: AXUIElement, titles: Set<String>) async throws -> AXUIElement? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else {
            return nil // 不抛出错误，因为可能没有子元素
        }

        for child in childArray {
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title) == .success,
               let titleString = title as? String, titles.contains(titleString) {
                
                // 找到匹配的菜单项，先尝试返回，如果返回为空，则继续在子菜单中查找
                if let found = try await searchMenuItemRecursively(child, titles: titles) {
                    return found
                } else {
                    return child
                }
            }
            
            // 如果当前子元素不是目标菜单项，则继续递归查找
            if let found = try await searchMenuItemRecursively(child, titles: titles) {
                return found
            }
        }
        return nil
    }

    private func isMenuItemEnabled(_ item: AXUIElement) -> Bool {
        var enabled: CFTypeRef?
        if AXUIElementCopyAttributeValue(item, kAXEnabledAttribute as CFString, &enabled) == .success,
           let isEnabled = enabled as? Bool {
            return isEnabled
        }
        return false
    }
}

// 定义可能的错误类型
enum MenuActionError: Error {
    case invalidAction
    case menuBarNotFound
    case childrenNotFound
    case menuItemNotFound
    case menuItemNotEnabled
    case actionFailed
    case clipboardNotUpdated
}

