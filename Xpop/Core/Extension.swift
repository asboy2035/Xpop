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
    var options: [[String: Any]]?
    var optionsTitle: LocalizedStringKey?
    var entitlements: [String]?
    var actions: [[String: Any]]?
    
    var url: String?
    var keyCombo: String?
    var keyCombos: [String]?
    var shortcutName: String?
    var serviceName: String?
    var shellScript: String?
    var interpreter: String?
    
    var _buildin_type: String?
    // MARK: - Plugin State
    var isEnabled: Bool = false
    
    var localizedName: String {
        NSLocalizedString(name!, comment: "")
    }
    
    // MARK: - Initializer
    init(name: String?,
         icon: String? = nil,
         identifier: String? = nil,
         description: LocalizedStringKey? = nil,
         macosVersion: String? = nil,
         popclipVersion: Int? = nil,
         options: [[String: Any]]? = nil,
         optionsTitle: LocalizedStringKey? = nil,
         entitlements: [String]? = nil,
         actions: [[String: Any]]? = nil,
         url: String? = nil,
         keyCombo: String? = nil,
         keyCombos: [String]? = nil,
         shortcutName: String? = nil,
         serviceName: String? = nil,
         shellScript: String? = nil,
         interpreter: String? = nil,
         isEnabled: Bool = false,
         _buildin_type: String? = nil) {
        // Required property
        self.name = name
        
        // 当 icon 为空时，使用 name 来赋值 icon
        self.icon = icon ?? name
        
        // Optional properties
        self.identifier = identifier
        self.description = description
        self.macosVersion = macosVersion
        self.popclipVersion = popclipVersion
        self.options = options
        self.optionsTitle = optionsTitle
        self.entitlements = entitlements
        self.actions = actions
        self.url = url
        self.keyCombo = keyCombo
        self.keyCombos = keyCombos
        self.shortcutName = shortcutName
        self.serviceName = serviceName
        self.shellScript = shellScript
        self.interpreter = interpreter
        
        self._buildin_type = _buildin_type
        // Plugin state
        self.isEnabled = isEnabled
    }
    
    // MARK: - 判断 action 类型
    func actionType() -> String {
        if self.url != nil {
            self._buildin_type = "url"
            return "url"
        } else if self.keyCombo != nil || self.keyCombos != nil {
            self._buildin_type = "keycombo"
            return "keyCombo"
        } else if self.shortcutName != nil {
            self._buildin_type = "shortcut"
            return "shortcut"
        } else if self.serviceName != nil {
            self._buildin_type = "service"
            return "service"
        } else {
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
        default:
            print("Unknown action type")
        }
    }
    
    // MARK: - 打开 URL
    func openURL(selectedText: String) {
        // 对文本进行 URL 编码
        let encodedText = selectedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // 替换 URL 中的占位符
        
        let formattedURL = self.url!
            .replacingOccurrences(of: "***", with: encodedText)
            .replacingOccurrences(of: "{popclip text}", with: encodedText)
            .replacingOccurrences(of: "{xpop text}", with: encodedText)
        
        // 检查 URL 是否有效
        guard let urlObject = URL(string: formattedURL) else {
            print("Invalid URL: \(formattedURL)")
            return
        }
        
        NSWorkspace.shared.open(urlObject)
    }
    
    // MARK: - 模拟按键组合
    private func simulateKeyCombo() {
        if let keyCombo = self.keyCombo {
            print("Simulating key combo: \(keyCombo)")
            // 这里可以调用系统 API 来模拟按键组合
        } else if let keyCombos = self.keyCombos {
            for combo in keyCombos {
                print("Simulating key combo: \(combo)")
                // 这里可以调用系统 API 来模拟按键组合
            }
        }
    }
    
    // MARK: - 运行快捷指令
    private func runShortcut() {
        guard let shortcutName = self.shortcutName else {
            print("Shortcut name is missing")
            return
        }
        print("Running shortcut: \(shortcutName)")
        // 这里可以调用系统 API 来运行快捷指令
    }
    
    // MARK: - 运行服务
    private func runService() {
        guard let serviceName = self.serviceName else {
            print("Service name is missing")
            return
        }
        print("Running service: \(serviceName)")
        // 这里可以调用系统 API 来运行服务
    }
    
    // MARK: - 将插件信息转换为 YAML 字符串
    func toYAML() throws -> String {
        var yamlDict = [String: Any]()
        
        // 添加必填字段
        if let name = self.name {
            yamlDict["name"] = name
        }
        
        // 添加可选字段
        if let icon = self.icon {
            yamlDict["icon"] = icon
        }
        if let identifier = self.identifier {
            yamlDict["identifier"] = identifier
        }
        if let description = self.description {
            yamlDict["description"] = String(describing: description)
        }
        if let macosVersion = self.macosVersion {
            yamlDict["macos version"] = macosVersion
        }
        if let popclipVersion = self.popclipVersion {
            yamlDict["popclip version"] = popclipVersion
        }
        if let options = self.options {
            yamlDict["options"] = options
        }
        if let optionsTitle = self.optionsTitle {
            yamlDict["options title"] = String(describing: optionsTitle)
        }
        if let entitlements = self.entitlements {
            yamlDict["entitlements"] = entitlements
        }
        if let actions = self.actions {
            yamlDict["actions"] = actions
        }
        if let url = self.url {
            yamlDict["url"] = url
        }
        if let keyCombo = self.keyCombo {
            yamlDict["key combo"] = keyCombo
        }
        if let keyCombos = self.keyCombos {
            yamlDict["key combos"] = keyCombos
        }
        if let shortcutName = self.shortcutName {
            yamlDict["shortcut name"] = shortcutName
        }
        if let serviceName = self.serviceName {
            yamlDict["service name"] = serviceName
        }

        if let shellScript = self.shellScript {
            yamlDict["shell script"] = shellScript
        }
        if let interpreter = self.interpreter {
            yamlDict["interpreter"] = interpreter
        }
        
        // 将字典转换为 YAML 字符串
        do {
            let yamlString = try Yams.dump(object: yamlDict)
            // 在 YAML 字符串前添加 #popclip 注释
            return "#popclip\n" + yamlString
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
                return "YAML string must start with '#popclip' or '# popclip'."
            case .invalidYAML(let message):
                return "Invalid YAML format: \(message)"
            case .missingRequiredField(let field):
                return "Missing required field '\(field)'."
            case .fileWriteFailed(let message):
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

class ExtensionManager: ObservableObject {
    // MARK: - Shared Instance
    static let shared = ExtensionManager()
    
    // MARK: - Properties
    @Published var extensions: [String: Extension] = [:]
    @Published var extensionList: [ExtensionItem] = []
    
    // MARK: - UserDefaults Key
    private let extensionListKey = "extensionList"
    
    init() {
        // 加载系统默认的插件
        self.loadExtensionList()
        self.loadBuildinExtensions()
        // 加载插件
        self.loadExtensions()
    }
    
    func loadBuildinExtensions() {
        // 搜索插件
        let searchExtension = Extension(
            name: "Search",
            icon: "symbol:magnifyingglass",
            url: "https://www.google.com/search?q={xpop text}"
        )
        let searchExtensionItem = ExtensionItem(
            name: "_XPOP_BUILDIN_SEARCH",
            isEnabled: true
        )
        
        // 翻译插件
        let translateExtension = Extension(
            name: "Translate",
            icon: "symbol:translate",
            _buildin_type: "_buildin"
        )
        let translateExtensionItem = ExtensionItem(
            name: "_XPOP_BUILDIN_TRANSLATE",
            isEnabled: true
        )
        
        // 检查并添加搜索插件
        if !extensionList.contains(where: { $0.name == searchExtensionItem.name }) {
            extensionList.append(searchExtensionItem)
        }
        if extensions[searchExtensionItem.name] == nil {
            extensions[searchExtensionItem.name] = searchExtension
        }
        
        // 检查并添加翻译插件
        if !extensionList.contains(where: { $0.name == translateExtensionItem.name }) {
            extensionList.append(translateExtensionItem)
        }
        if extensions[translateExtensionItem.name] == nil {
            extensions[translateExtensionItem.name] = translateExtension
        }
        
        // 保存到 UserDefaults
        saveExtensionList()
    }
    
    // MARK: - Load Extensions
    func loadExtensions() {
        let extensionsDirectory = getExtensionsDirectory()
        // 检查目录是否存在
        guard FileManager.default.fileExists(atPath: extensionsDirectory.path) else {
            print("Extensions directory does not exist.")
            return
        }
        
        // 获取所有插件文件夹
        do {
            let pluginFolders = try FileManager.default.contentsOfDirectory(atPath: extensionsDirectory.path)
            for folder in pluginFolders {
                if folder.hasSuffix(".xpopext") {
                    let pluginDirectory = extensionsDirectory.appendingPathComponent(folder)
                    let configFilePath = pluginDirectory.appendingPathComponent("Config.yaml")
                    // 检查配置文件是否存在
                    if FileManager.default.fileExists(atPath: configFilePath.path) {
                        do {
                            let yamlString = try String(contentsOf: configFilePath, encoding: .utf8)
                            let extensionInstance = try ExtensionManager.fromYAML(yamlString)
                            extensions[folder] = extensionInstance
                        } catch {
                            print("Failed to load extension from \(folder): \(error)")
                        }
                    }
                }
            }
        } catch {
            print("Failed to load extensions: \(error)")
        }
    }
    
    // MARK: - Load Extension List
    func loadExtensionList() {
//        UserDefaults.standard.removeObject(forKey: "extensionList")
        if let savedData = UserDefaults.standard.data(forKey: extensionListKey) {
            // 如果 UserDefaults 中有保存的数据，则解码并加载
            let decoder = JSONDecoder()
            if let decodedList = try? decoder.decode([ExtensionItem].self, from: savedData) {
                self.extensionList = decodedList
            }
        }
        
        // 找到 extensions 中存在但 extensionList 中不存在的插件
        let newExtensions = extensions
            .filter { (key, _) in
                !self.extensionList.contains { $0.name == key }
            }
            .map { (key, ext) in
                ExtensionItem(name: key, isEnabled: ext.isEnabled)
            }
        
        // 将新插件添加到 extensionList 的末尾
        self.extensionList.append(contentsOf: newExtensions)
        
        // 保存到 UserDefaults
        saveExtensionList()
    }
    
    // MARK: - Save Extension List to UserDefaults
    private func saveExtensionList() {
        let encoder = JSONEncoder()
        if let encodedData = try? encoder.encode(extensionList) {
            UserDefaults.standard.set(encodedData, forKey: extensionListKey)
        }
    }
    
    // MARK: - Update Extension State
    func updateExtensionState(extName: String, isEnabled: Bool) {
        if let ext = extensions[extName] {
            ext.isEnabled = isEnabled
            extensions[extName] = ext
        }
        if let index = extensionList.firstIndex(where: { $0.name == extName }) {
            extensionList[index].isEnabled = isEnabled
        }
        saveExtensionList()
    }
    
    func moveExtensions(from source: IndexSet, to destination: Int) {
        withAnimation {
            extensionList.move(fromOffsets: source, toOffset: destination)
            saveExtensionList()
        }
    }
    
    // MARK: - Delete Extension
    func deleteExtension(extensionName: String) {
        // 1. 从 extensions 字典中移除插件
        extensions.removeValue(forKey: extensionName)
        
        // 2. 从 extensionList 数组中移除插件
        if let index = extensionList.firstIndex(where: { $0.name == extensionName }) {
            extensionList.remove(at: index)
        }
        
        // 3. 保存更新后的 extensionList 到 UserDefaults
        saveExtensionList()
        
        // 4. 从文件系统中删除插件目录
        let extensionsDirectory = getExtensionsDirectory()
        let pluginDirectory = extensionsDirectory.appendingPathComponent(extensionName)
        
        // 检查插件目录是否存在
        guard FileManager.default.fileExists(atPath: pluginDirectory.path) else {
            print("Plugin directory '\(extensionName)' does not exist.")
            return
        }
        
        // 删除插件目录
        do {
            try FileManager.default.removeItem(at: pluginDirectory)
            print("Deleted plugin directory at: \(pluginDirectory.path)")
        } catch {
            print("Failed to delete plugin directory '\(extensionName)': \(error.localizedDescription)")
        }
    }
    
    func getExtensionByName(name: String) -> Extension {
        return extensions[name]!
    }
    
    // MARK: - 获取 Extensions 目录
    private func getExtensionsDirectory() -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let extensionsDirectory = appSupportURL
            .appendingPathComponent("Xpop")
            .appendingPathComponent("Extensions")
        
        // 检查目录是否存在，如果不存在则创建
        if !FileManager.default.fileExists(atPath: extensionsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create Extensions directory: \(error.localizedDescription)")
            }
        }
        
        return extensionsDirectory
    }
    // MARK: - 检查字符串是否以 #popclip 或 # popclip 开头
    static func isExtensionString(_ yamlString: String) -> Bool {
        return yamlString.starts(with: "#popclip") || yamlString.starts(with: "# popclip")
    }
    
    // MARK: - 从 YAML 字符串解析扩展
    static func fromYAML(_ yamlString: String) throws -> Extension {
        // 检查是否以 #popclip 或 # popclip 开头
        guard isExtensionString(yamlString) else {
            throw Extension.ExtensionError.invalidHeader
        }
        
        // 解析 YAML 字符串
        let yamlDict: [String: Any]
        do {
            if let parsedDict = try Yams.load(yaml: yamlString) as? [String: Any] {
                yamlDict = parsedDict
            } else {
                throw Extension.ExtensionError.invalidYAML("Parsed YAML is not a dictionary.")
            }
        } catch {
            // 捕获 Yams 的原始错误并返回
            throw Extension.ExtensionError.invalidYAML("YAML parsing failed: \(error)")
        }
        
        // 验证必填字段
        guard yamlDict["name"] is String else {
            throw Extension.ExtensionError.missingRequiredField("name")
        }
        
        // 创建 Extension 对象
        let xpopExtension = Extension(
            name: yamlDict["name"] as? String,
            icon: yamlDict["icon"] as? String,
            identifier: yamlDict["identifier"] as? String,
            description: (yamlDict["description"] as? String).map { LocalizedStringKey($0) },
            macosVersion: yamlDict["macos version"] as? String,
            popclipVersion: yamlDict["popclip version"] as? Int,
            options: yamlDict["options"] as? [[String: Any]],
            optionsTitle: (yamlDict["options title"] as? String).map { LocalizedStringKey($0) },
            entitlements: yamlDict["entitlements"] as? [String],
            actions: yamlDict["actions"] as? [[String: Any]],
            url: yamlDict["url"] as? String,
            keyCombo: yamlDict["key combo"] as? String,
            keyCombos: yamlDict["key combos"] as? [String],
            shortcutName: yamlDict["shortcut name"] as? String,
            serviceName: yamlDict["service name"] as? String,
            
            shellScript: yamlDict["shell script"] as? String,
            interpreter: yamlDict["interpreter"] as? String
        )
        
        return xpopExtension
    }
    
    // MARK: - 生成随机字符串
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    // MARK: - 安装插件
    func install(ext: Extension) throws {
        let extensionsDirectory = getExtensionsDirectory()
        
        // 如果目录不存在，则创建
        if !FileManager.default.fileExists(atPath: extensionsDirectory.path) {
            try FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // 生成插件文件夹名称
        guard let name = ext.name else {
            throw Extension.ExtensionError.missingRequiredField("name")
        }
        let sanitizedName = name.replacingOccurrences(of: " ", with: "-")
        let randomSuffix = generateRandomString(length: 8)
        let folderName = "\(sanitizedName).\(randomSuffix).xpopext"
        let pluginDirectory = extensionsDirectory.appendingPathComponent(folderName)
        
        // 检查是否存在同名插件
        let existingPluginDirectories = try FileManager.default.contentsOfDirectory(atPath: extensionsDirectory.path)
        for existingDirectory in existingPluginDirectories {
            if existingDirectory.hasPrefix("\(sanitizedName).") && existingDirectory.hasSuffix(".xpopext") {
                // 删除已存在的同名插件
                let existingPluginDirectory = extensionsDirectory.appendingPathComponent(existingDirectory)
                try FileManager.default.removeItem(at: existingPluginDirectory)
                print("Removed existing plugin at: \(existingPluginDirectory.path)")
            }
        }
        
        // 创建插件文件夹
        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // 将插件信息转换为 YAML 字符串
        let yamlString = try ext.toYAML()
        
        // 写入 Config.yaml 文件
        let configFilePath = pluginDirectory.appendingPathComponent("Config.yaml")
        try yamlString.write(to: configFilePath, atomically: true, encoding: .utf8)
        
        // 重新加载插件
        loadExtensions()
        loadExtensionList()
    }
    
    // MARK: - 卸载插件
    func uninstall(extension: Extension) throws {
        let extensionsDirectory = getExtensionsDirectory()
        
        // 检查目录是否存在
        guard FileManager.default.fileExists(atPath: extensionsDirectory.path) else {
            throw Extension.ExtensionError.fileWriteFailed("Extensions directory does not exist.")
        }
        
        // 获取插件名称并生成插件目录名称
        guard let name = `extension`.name else {
            throw Extension.ExtensionError.missingRequiredField("name")
        }
        let sanitizedName = name.replacingOccurrences(of: " ", with: "-")
        
        // 查找匹配的插件目录
        let existingPluginDirectories = try FileManager.default.contentsOfDirectory(atPath: extensionsDirectory.path)
        for existingDirectory in existingPluginDirectories {
            if existingDirectory.hasPrefix("\(sanitizedName).") && existingDirectory.hasSuffix(".xpopext") {
                // 找到匹配的插件目录
                let pluginDirectory = extensionsDirectory.appendingPathComponent(existingDirectory)
                
                // 删除插件目录
                try FileManager.default.removeItem(at: pluginDirectory)
                print("Uninstalled plugin at: \(pluginDirectory.path)")
                
                // 重新加载插件
                loadExtensions()
                return
            }
        }
        
        // 如果没有找到匹配的插件目录
        throw Extension.ExtensionError.fileWriteFailed("Extension with name '\(name)' not found.")
    }
    
    // MARK: - 打开 URL
    static func openURL(_ url: String, selectedText: String, additionalParameter: Any? = nil) {
        // 替换 URL 中的占位符
        let formattedURL = url
            .replacingOccurrences(of: "***", with: selectedText)
            .replacingOccurrences(of: "{popclip text}", with: selectedText)
            .replacingOccurrences(of: "{xclip text}", with: selectedText)
        
        // 检查 URL 是否有效
        guard let urlObject = URL(string: formattedURL) else {
            print("Invalid URL: \(formattedURL)")
            return
        }
        
        NSWorkspace.shared.open(urlObject)
    }
}

class BuiltInAction {
    static let actions: [String: () -> Void] = [
        "Translate": {
                Task { @MainActor in
                    let winManager = AppDelegate.shared
                    winManager.hideWindow_new()
                    
                    var selectedText: String?
                    selectedText = winManager.selectedText
                    
                    print("Selected Text: \(selectedText ?? "None")")
                    winManager.panelManager.showPanel(query: selectedText!)
                    print("执行翻译功能")
                }
            }
    ]
}
