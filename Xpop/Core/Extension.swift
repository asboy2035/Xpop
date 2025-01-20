//
//  Extension.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Foundation
import SwiftUI
import Yams

class Extension: Identifiable, Codable {
    // MARK: - Required Properties

    let name: String?

    // MARK: - Optional Properties

    var icon: String?
    var identifier: String?
    var description: String? // 改为 String 类型
    var macosVersion: String?
    var popclipVersion: Int?

    var entitlements: [String]?
    var action: [String: String]? // 改为 [String: String] 类型
    var url: String?
    var keyCombo: String?
    var keyCombos: [String]?
    var shortcutName: String?
    var serviceName: String?
    var shellScript: String?
    var shellScriptFile: String?
    var interpreter: String?

    var options: [Option]?

    var folderName: String?
    var buintinType: String?

    // MARK: - Plugin State

    var isEnabled: Bool = false

    var localizedName: String {
        NSLocalizedString(name ?? "", comment: "")
    }

    let logger = Logger.shared
    let ssExecutor = ShellScriptExecutor.shared

    // MARK: - Initializer

    init(name: String?,
         icon: String? = nil,
         identifier: String? = nil,
         description: String? = nil, // 改为 String 类型
         macosVersion: String? = nil,
         popclipVersion: Int? = nil,
         entitlements: [String]? = nil,
         action: [String: String]? = nil, // 改为 [String: String] 类型
         url: String? = nil,
         keyCombo: String? = nil,
         keyCombos: [String]? = nil,
         shortcutName: String? = nil,
         serviceName: String? = nil,
         shellScript: String? = nil,
         shellScriptFile: String? = nil,
         interpreter: String? = nil,
         options: [Option]? = nil,
         isEnabled: Bool = false,
         builtinType: String? = nil) {
        self.name = name
        self.icon = icon
        self.identifier = identifier
        self.description = description
        self.macosVersion = macosVersion
        self.popclipVersion = popclipVersion
        self.entitlements = entitlements
        self.action = action
        self.url = url
        self.keyCombo = keyCombo
        self.keyCombos = keyCombos
        self.shortcutName = shortcutName
        self.serviceName = serviceName
        self.options = options
        self.buintinType = builtinType
        self.isEnabled = isEnabled

        if let action = action {
            // 如果 action 存在，优先从 action 中提取脚本字段
            self.shellScript = action["shellscript"] ?? shellScript
            self.shellScriptFile = action["shell script file"] ?? shellScriptFile
            self.interpreter = action["interpreter"] ?? interpreter
        } else {
            // 如果 action 不存在，直接从最外层的字段中提取
            self.shellScript = shellScript
            self.shellScriptFile = shellScriptFile
            self.interpreter = interpreter
        }
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case name
        case icon
        case identifier
        case description
        case macosVersion
        case popclipVersion
        case entitlements
        case action
        case url
        case keyCombo
        case keyCombos
        case shortcutName
        case serviceName
        case shellScript
        case shellScriptFile
        case interpreter
        case options
        case folderName
        case buintinType
        case isEnabled
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        macosVersion = try container.decodeIfPresent(String.self, forKey: .macosVersion)
        popclipVersion = try container.decodeIfPresent(Int.self, forKey: .popclipVersion)
        entitlements = try container.decodeIfPresent([String].self, forKey: .entitlements)
        action = try container.decodeIfPresent([String: String].self, forKey: .action)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        keyCombo = try container.decodeIfPresent(String.self, forKey: .keyCombo)
        keyCombos = try container.decodeIfPresent([String].self, forKey: .keyCombos)
        shortcutName = try container.decodeIfPresent(String.self, forKey: .shortcutName)
        serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName)
        shellScript = try container.decodeIfPresent(String.self, forKey: .shellScript)
        shellScriptFile = try container.decodeIfPresent(String.self, forKey: .shellScriptFile)
        interpreter = try container.decodeIfPresent(String.self, forKey: .interpreter)
        options = try container.decodeIfPresent([Option].self, forKey: .options)
        folderName = try container.decodeIfPresent(String.self, forKey: .folderName)
        buintinType = try container.decodeIfPresent(String.self, forKey: .buintinType)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
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

    // MARK: - YAML Conversion

    func toYAML() throws -> String {
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(self)
        return "#xpop\n" + yamlString
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

class Option: Codable {
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
        self.type = type.lowercased()
        self.label = label
        self.description = description
        self.defaultValue = defaultValue
        self.values = values
        self.valueLabels = valueLabels
    }
}
