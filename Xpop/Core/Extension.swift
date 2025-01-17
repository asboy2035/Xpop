//
//  Extension.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Foundation
import SwiftUI
import Yams

class Extension: Identifiable {
    // MARK: - Required Properties

    let name: String?

    // MARK: - Optional Properties

    var icon: String?
    var identifier: String?
    var description: LocalizedStringKey?
    var macosVersion: String?
    var popclipVersion: Int?

    var entitlements: [String]?
    var action: [String: Any]?

    var url: String?
    var keyCombo: String?
    var keyCombos: [String]?
    var shortcutName: String?
    var serviceName: String?
    var shellScript: String?
    var shellScriptFile: String? // 新增：表示 shell 脚本文件的路径
    var interpreter: String?
    
    var options: [Option]?

    var folderName: String? // 唯一识别符，含有随机生成字符串

    var buintinType: String?

    // MARK: - Plugin State

    var isEnabled: Bool = false

    var localizedName: String {
        NSLocalizedString(name!, comment: "")
    }

    let logger = Logger.shared

    let ssExecutor = ShellScriptExecutor.shared

    // MARK: - Initializer

    init(name: String?,
         icon: String? = nil,
         identifier: String? = nil,
         description: LocalizedStringKey? = nil,
         macosVersion: String? = nil,
         popclipVersion: Int? = nil,
         entitlements: [String]? = nil,
         action: [String: Any]? = nil,
         url: String? = nil,
         keyCombo: String? = nil,
         keyCombos: [String]? = nil,
         shortcutName: String? = nil,
         serviceName: String? = nil,
         shellScript: String? = nil,
         shellScriptFile: String? = nil, // 新增：初始化 shellScriptFile
         interpreter: String? = nil,
         options: [Option]? = nil,
         isEnabled _: Bool = false,
         builtinType: String? = nil) {
        // Required property
        self.name = name

        // 当 icon 为空时，使用 name 来赋值 icon
        if let name = name, icon == nil {
            let words = name.components(separatedBy: " ")
            if words.count > 1 {
                // 如果 name 有多个单词，取前三个单词的首字母并大写
                let initials = words.prefix(3).map { String($0.first!).uppercased() }
                self.icon = initials.joined()
            } else {
                // 如果 name 只有一个单词，取前8个字符
                self.icon = String(name.prefix(8))
            }
        } else {
            self.icon = icon
        }

        // Optional properties
        self.identifier = identifier
        self.description = description
        self.macosVersion = macosVersion
        self.popclipVersion = popclipVersion
        self.options = options
        self.entitlements = entitlements
        self.action = action
        self.url = url
        self.keyCombo = keyCombo
        self.keyCombos = keyCombos
        self.shortcutName = shortcutName
        self.serviceName = serviceName

        buintinType = builtinType

        // 处理脚本字段
        if let action = action {
            // 如果 action 存在，优先从 action 中提取脚本字段
            self.shellScript = action["shellscript"] as? String ?? shellScript
            self.shellScriptFile = action["shell script file"] as? String ?? shellScriptFile
            self.interpreter = action["interpreter"] as? String ?? interpreter
        } else {
            // 如果 action 不存在，直接从最外层的字段中提取
            self.shellScript = shellScript
            self.shellScriptFile = shellScriptFile
            self.interpreter = interpreter
        }
    }

    // MARK: - 判断 action 类型

    func actionType() -> String {
        if url != nil {
            buintinType = "url"
            return "url"
        } else if keyCombo != nil || keyCombos != nil {
            buintinType = "keycombo"
            return "keyCombo"
        } else if shortcutName != nil {
            buintinType = "shortcut"
            return "shortcut"
        } else if serviceName != nil {
            buintinType = "service"
            return "service"
        } else if shellScript != nil || shellScriptFile != nil {
            buintinType = "shellScript" // 新增：shellScript 类型
            return "shellScript"
        } else {
            buintinType = "unknown"
            return "unknown"
        }
    }

    // MARK: - 执行插件

    func run(selectedText: String?) {
        let type = actionType()
        switch type {
        case "url":
            openURL(selectedText: selectedText!)
        case "keyCombo":
            simulateKeyCombo()
        case "shortcut":
            runShortcut()
        case "service":
            runService()
        case "shellScript": // 新增：执行 shellScript
            runShellScript()
        default:
            print("Unknown action type")
        }
    }

    // MARK: - 打开 URL

    func openURL(selectedText: String) {
        // 对文本进行 URL 编码
        let encodedText = selectedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // 替换 URL 中的占位符

        var formattedURL = url!
            .replacingOccurrences(of: "***", with: encodedText)
            .replacingOccurrences(of: "{popclip text}", with: encodedText)
            .replacingOccurrences(of: "{xpop text}", with: encodedText)

        // 替换 options 中的占位符
        if let options = options {
            for option in options {
                if let defaultValue = option.defaultValue {
                    formattedURL = formattedURL.replacingOccurrences(of: "{popclip option \(option.label)}", with: defaultValue)
                }
            }
        }
        
        // 检查 URL 是否有效
        guard let urlObject = URL(string: formattedURL) else {
            print("Invalid URL: \(formattedURL)")
            return
        }

        NSWorkspace.shared.open(urlObject)
    }

    // MARK: - 模拟按键组合

    private func simulateKeyCombo() {
        if let keyCombo = keyCombo {
            print("Simulating key combo: \(keyCombo)")
            // 这里可以调用系统 API 来模拟按键组合
        } else if let keyCombos = keyCombos {
            for combo in keyCombos {
                print("Simulating key combo: \(combo)")
                // 这里可以调用系统 API 来模拟按键组合
            }
        }
    }

    // MARK: - 运行快捷指令

    private func runShortcut() {
        guard let shortcutName = shortcutName else {
            print("Shortcut name is missing")
            return
        }
        print("Running shortcut: \(shortcutName)")
        // 这里可以调用系统 API 来运行快捷指令
    }

    // MARK: - 运行服务

    private func runService() {
        guard let serviceName = serviceName else {
            print("Service name is missing")
            return
        }
        print("Running service: \(serviceName)")
        // 这里可以调用系统 API 来运行服务
    }

    // MARK: - 运行 Shell 脚本

    private func runShellScript() {
        Task {
            do {
                let extName = ExtensionManager.shared.getExtensionDir(name: name!)
                let output = try await ssExecutor.runShellScript(
                    script: shellScript,
                    scriptFile: shellScriptFile,
                    extensionName: extName
                )
                logger.log("Shell script output: %{public}@", output, type: .info)
            } catch {
                logger.log("Error running shell script: %{public}@", error.localizedDescription, type: .error)
            }
        }
    }

    // MARK: - 将插件信息转换为 YAML 字符串

    func toYAML() throws -> String {
        var yamlDict = [String: Any]()

        // 添加必填字段
        if let name = name {
            yamlDict["name"] = name
        }

        // 添加可选字段
        if let icon = icon {
            yamlDict["icon"] = icon
        }
        if let identifier = identifier {
            yamlDict["identifier"] = identifier
        }
        if let description = description {
            yamlDict["description"] = String(describing: description)
        }
        if let macosVersion = macosVersion {
            yamlDict["macos version"] = macosVersion
        }
        if let popclipVersion = popclipVersion {
            yamlDict["popclip version"] = popclipVersion
        }
        if let options = options {
            yamlDict["options"] = options
        }
        if let entitlements = entitlements {
            yamlDict["entitlements"] = entitlements
        }
        if let action = action {
            yamlDict["action"] = action
        }
        if let url = url {
            yamlDict["url"] = url
        }
        if let keyCombo = keyCombo {
            yamlDict["key combo"] = keyCombo
        }
        if let keyCombos = keyCombos {
            yamlDict["key combos"] = keyCombos
        }
        if let shortcutName = shortcutName {
            yamlDict["shortcut name"] = shortcutName
        }
        if let serviceName = serviceName {
            yamlDict["service name"] = serviceName
        }
        if let shellScript = shellScript {
            yamlDict["shell script"] = shellScript
        }
        if let shellScriptFile = shellScriptFile { // 新增：添加 shellScriptFile 到 YAML
            yamlDict["shell script file"] = shellScriptFile
        }
        if let interpreter = interpreter {
            yamlDict["interpreter"] = interpreter
        }

        // 将字典转换为 YAML 字符串
        do {
            let yamlString = try Yams.dump(object: yamlDict)
            // 在 YAML 字符串前添加 #popclip 注释
            return "#xpop\n" + yamlString
        } catch {
            throw ExtensionError.invalidYAML("Failed to convert to YAML: \(error)")
        }
    }

    // MARK: - 错误类型

    enum ExtensionError: Error, LocalizedError {
        case invalidHeader
        case invalidYAML(String)
        case missingRequiredField(String)
        case fileWriteFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidHeader:
                return "YAML string must start with '#popclip' or '# popclip' or '#xpop' or '# xpop'."
            case let .invalidYAML(message):
                return "Invalid YAML format: \(message)"
            case let .missingRequiredField(field):
                return "Missing required field '\(field)'."
            case let .fileWriteFailed(message):
                return "Failed to write to file: \(message)"
            }
        }
    }
}

struct ExtensionItem: Identifiable, Decodable, Encodable {
    var id = UUID()
    let name: String
    var isEnabled: Bool
}

class Option {
    /// The type of the option. See `OptionType` for possible values.
    let type: String

    /// The label to appear in the UI for this option.
    var label: String
    
    /// A longer description to appear in the UI to explain this option.
    var description: String?
    
    /// The default value of the option.
    /// - For string options, defaults to an empty string if omitted.
    /// - For boolean options, defaults to `true` if omitted.
    /// - For multiple options, defaults to the top item in the list if omitted.
    /// - A password field may not have a default value.
    var defaultValue: String?
    
    /// Array of strings representing the possible values for the multiple choice option.
    /// Required if the option type is `multiple`.
    var values: [String]?
    
    /// Array of "human friendly" strings corresponding to the multiple choice values.
    /// This is used only in the UI and is not passed to the script.
    /// If omitted, the option values themselves are shown.
    var valueLabels: [String]?
    
    // MARK: - Initializer
    /// Initializes an `Option` with required and optional properties.
    /// - Parameters:
    ///   - type: The type of the option.
    ///   - label: The label to appear in the UI for this option.
    ///   - description: A longer description to appear in the UI to explain this option.
    ///   - defaultValue: The default value of the option.
    ///   - values: Array of strings representing the possible values for the multiple choice option.
    ///   - valueLabels: Array of "human friendly" strings corresponding to the multiple choice values.
    init(
        type: String,
        label: String,
        description: String? = nil,
        defaultValue: String? = nil,
        values: [String]? = nil,
        valueLabels: [String]? = nil
    ) {
        self.type = type
        self.label = label
        self.description = description
        self.defaultValue = defaultValue
        self.values = values
        self.valueLabels = valueLabels
    }
}
