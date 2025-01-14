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
    var action: [String: Any]?
    
    var url: String?
    var keyCombo: String?
    var keyCombos: [String]?
    var shortcutName: String?
    var serviceName: String?
    var shellScript: String?
    var shellScriptFile: String? // 新增：表示 shell 脚本文件的路径
    var interpreter: String?
    
    var folderName: String? // 唯一识别符，含有随机生成字符串
    
    var _buildin_type: String?
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
         options: [[String: Any]]? = nil,
         optionsTitle: LocalizedStringKey? = nil,
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
         isEnabled: Bool = false,
         _buildin_type: String? = nil) {
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
        self.optionsTitle = optionsTitle
        self.entitlements = entitlements
        self.action = action
        self.url = url
        self.keyCombo = keyCombo
        self.keyCombos = keyCombos
        self.shortcutName = shortcutName
        self.serviceName = serviceName
        
        self._buildin_type = _buildin_type
        
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
        } else if self.shellScript != nil || self.shellScriptFile != nil {
            self._buildin_type = "shellScript" // 新增：shellScript 类型
            return "shellScript"
        } else {
            self._buildin_type = "unknown"
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
    
    // MARK: - 运行 Shell 脚本
    private func runShellScript() {
        Task {
            do {
                let extName = ExtensionManager.shared.getExtensionDir(name: name!)
                let output = try await ssExecutor.runShellScript(script: shellScript, scriptFile: shellScriptFile, extensionName: extName)
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
        if let action = self.action {
            yamlDict["action"] = action
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
        if let shellScriptFile = self.shellScriptFile { // 新增：添加 shellScriptFile 到 YAML
            yamlDict["shell script file"] = shellScriptFile
        }
        if let interpreter = self.interpreter {
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
    private let logger = Logger.shared
    
    // MARK: - Properties
    @Published var extensions: [String: Extension] = [:]
    @Published var extensionList: [ExtensionItem] = []
    
    // MARK: - UserDefaults Key
    private let extensionListKey = "extensionList"
    
    init() {
        self.loadExtensions()
        self.loadBuildinExtensions()
        self.loadExtensionList()
        // 保存到 UserDefaults
        saveExtensionList()
        
    }
    
    func loadBuildinExtensions() {
//        UserDefaults.standard.removeObject(forKey: "extensionList")
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
        
        // Copy
        let copyExtension = Extension(
            name: "Copy",
            icon: "symbol:document.on.document",
            _buildin_type: "_buildin"
        )
        let copyExtensionItem = ExtensionItem(
            name: "_XPOP_BUILDIN_COPY",
            isEnabled: true
        )
        
        // Cut
        let cutExtension = Extension(
            name: "Cut",
            icon: "symbol:scissors",
            _buildin_type: "_buildin"
        )
        let cutExtensionItem = ExtensionItem(
            name: "_XPOP_BUILDIN_CUT",
            isEnabled: true
        )
        
        // Paste
        let pasteExtension = Extension(
            name: "Paste",
            icon: "symbol:document.on.clipboard",
            _buildin_type: "_buildin"
        )
        let pasteExtensionItem = ExtensionItem(
            name: "_XPOP_BUILDIN_PASTE",
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
        
        // 检查并添加copy插件
        if !extensionList.contains(where: { $0.name == copyExtensionItem.name }) {
            extensionList.append(copyExtensionItem)
        }
        if extensions[copyExtensionItem.name] == nil {
            extensions[copyExtensionItem.name] = copyExtension
        }
        
        // 检查并添加cut插件
        if !extensionList.contains(where: { $0.name == cutExtensionItem.name }) {
            extensionList.append(cutExtensionItem)
        }
        if extensions[cutExtensionItem.name] == nil {
            extensions[cutExtensionItem.name] = cutExtension
        }
        
        // 检查并添加paste插件
        if !extensionList.contains(where: { $0.name == pasteExtensionItem.name }) {
            extensionList.append(pasteExtensionItem)
        }
        if extensions[pasteExtensionItem.name] == nil {
            extensions[pasteExtensionItem.name] = pasteExtension
        }
    }
    
    // MARK: - Load Extensions
    func loadExtensions() {
        let extensionsDirectory = getExtensionsDirectory()
        // 检查目录是否存在
        guard FileManager.default.fileExists(atPath: extensionsDirectory.path) else {
            logger.log("Extensions directory does not exist.", type: .error)
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
                            logger.log("Failed to load extension from %{public}@: %{public}@:", folder, error.localizedDescription, type: .error)
                        }
                    }
                }
            }
        } catch {
            logger.log("Failed to load extensions: %{public}@", error.localizedDescription, type: .error)
        }
    }
    
    // MARK: - Load Extension List
    func loadExtensionList() {
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
            logger.log("Plugin directory %{public}@ does not exist.", extensionName, type: .info)
            return
        }
        
        // 删除插件目录
        do {
            try FileManager.default.removeItem(at: pluginDirectory)
            logger.log("Deleted plugin directory at: %{public}@", pluginDirectory.path, type: .info)
        } catch {
            logger.log("Failed to delete plugin directory %{public}@: %{public}@", extensionName, error.localizedDescription, type: .error)
        }
    }
    
    func getExtensionByName(name: String) -> Extension {
        return extensions[name]!
    }
    
    func getExtensionDir(name: String) -> String? {
        for (key, extensionValue) in extensions {
            if extensionValue.name == name {
                return key
            }
        }
        return nil // 如果没找到，返回 nil
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
                logger.log("Failed to create Extensions directory: %{public}@", error.localizedDescription, type: .error)
            }
        }
        
        return extensionsDirectory
    }
    // MARK: - 检查字符串是否以 #popclip 或 # popclip 开头
    static func isExtensionString(_ yamlString: String) -> Bool {
        return yamlString.starts(with: "#popclip") || yamlString.starts(with: "# popclip") || yamlString.starts(with: "#xpop") || yamlString.starts(with: "# xpop")
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
            action: yamlDict["action"] as? [String: Any],
            url: yamlDict["url"] as? String,
            keyCombo: yamlDict["key combo"] as? String,
            keyCombos: yamlDict["key combos"] as? [String],
            shortcutName: yamlDict["shortcut name"] as? String,
            serviceName: yamlDict["service name"] as? String,
            shellScript: yamlDict["shell script"] as? String,
            shellScriptFile: yamlDict["shell script file"] as? String,
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
    func install(ext: Extension) throws -> String {
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
                logger.log("Removed existing plugin at: %{public}@", existingPluginDirectory.path, type: .info)
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
        
        return folderName // 返回文件的目录
    }
    
    func install(url: URL) throws {
        let extensionsDirectory = getExtensionsDirectory()
        // 如果目录不存在，则创建
        if !FileManager.default.fileExists(atPath: extensionsDirectory.path) {
            try FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        let fileName = url.lastPathComponent // 获取完整文件名（包括扩展名）
        let name = url.deletingPathExtension().lastPathComponent // 去掉扩展名
        let pluginDirectory = extensionsDirectory.appendingPathComponent(fileName)

        // 检查是否存在同名插件
        let existingPluginDirectories = try FileManager.default.contentsOfDirectory(atPath: extensionsDirectory.path)
        for existingDirectory in existingPluginDirectories {
            if existingDirectory.hasPrefix(name) && existingDirectory.hasSuffix(".xpopext") {
                // 删除已存在的同名插件
                removeExtension(foldName: existingDirectory)
                let existingPluginDirectory = extensionsDirectory.appendingPathComponent(existingDirectory)
                try FileManager.default.removeItem(at: existingPluginDirectory)
                logger.log("Removed existing plugin at: %{public}@", existingPluginDirectory.path, type: .info)
            }
        }
        do {
            let fileManager = FileManager.default
            let destinationURL = extensionsDirectory.appendingPathComponent(url.lastPathComponent) // 构建完整的目标路径
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: url, to: destinationURL)
        } catch {
            print(url)
            print(extensionsDirectory)
            print(error.localizedDescription)
        }

        let configFilePath = pluginDirectory.appendingPathComponent("Config.yaml")
        let yamlString = try String(contentsOf: configFilePath, encoding: .utf8)
        let extensionInstance = try ExtensionManager.fromYAML(yamlString)
        extensions[fileName] = extensionInstance
        extensionList.append(ExtensionItem(name: fileName, isEnabled: extensionInstance.isEnabled))
        
        // 重新加载插件
        loadExtensions()
        loadExtensionList()
        saveExtensionList()
    }
    
    func removeExtension(foldName: String) {
        extensions.removeValue(forKey: foldName)
        extensionList = extensionList.filter{ $0.name != foldName }
        saveExtensionList()
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
                
                logger.log("Uninstalled plugin at: %{public}", pluginDirectory.path, type: .info)
                
                // 重新加载插件
                loadExtensions()
                return
            }
        }
        
        // 如果没有找到匹配的插件目录
        throw Extension.ExtensionError.fileWriteFailed("Extension with name '\(name)' not found.")
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
                winManager.panelManager.showPanel(query: selectedText!)
            }
        },
        "Copy": {
            Task {
                let kbManager = KeyboardManager.shared
                let winManager = AppDelegate.shared
                winManager.hideWindow_new()
                kbManager.simulateKeyPress(from: "command c")
            }
        },
        "Cut": {
            Task {
                let kbManager = KeyboardManager.shared
                let winManager = AppDelegate.shared
                winManager.hideWindow_new()
                kbManager.simulateKeyPress(from: "command x")
            }
        },
        "Paste": {
            Task {
                let kbManager = KeyboardManager.shared
                let winManager = AppDelegate.shared
                winManager.hideWindow_new()
                kbManager.simulateKeyPress(from: "command v")
            }
        }
    ]
}

class ShellScriptExecutor {
    static let shared = ShellScriptExecutor() // 单例实例
    private let fileManager = FileManager.default
    
    private init() {} // 防止外部初始化
    
    // MARK: - 运行 Shell 脚本
    func runShellScript(script: String?, scriptFile: String?, extensionName: String?) async throws -> String {
        // 获取软件名称
        guard let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String else {
            throw ShellScriptError.appNameNotFound
        }
        
        // 检查插件名称
        guard let extensionName = extensionName else {
            throw ShellScriptError.extensionNameMissing
        }
        
        // 获取 Application Support 目录
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let extensionsDirectory = appSupportURL
            .appendingPathComponent(appName)
            .appendingPathComponent("Extensions")
            .appendingPathComponent(extensionName)
        
        // 切换到插件目录
        let currentDirectory = fileManager.currentDirectoryPath
        defer {
            fileManager.changeCurrentDirectoryPath(currentDirectory)
        }
        
        let directoryChangeSuccess = fileManager.changeCurrentDirectoryPath(extensionsDirectory.path)
        if !directoryChangeSuccess {
            throw ShellScriptError.directoryChangeFailed(path: extensionsDirectory.path, error: NSError(domain: "FileManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to change directory"]))
        }
        
        // 读取脚本内容
        let scriptContent: String
        if let script = script {
            scriptContent = script
        } else if let scriptFile = scriptFile {
            let scriptURL = extensionsDirectory.appendingPathComponent(scriptFile)
            do {
                scriptContent = try String(contentsOf: scriptURL, encoding: .utf8)
            } catch {
                throw ShellScriptError.scriptFileReadFailed(path: scriptURL.path, error: error)
            }
        } else {
            throw ShellScriptError.scriptNotFound
        }
        
        // 执行脚本
        return try await executeShellScript(script: scriptContent)
    }
    
    
    // MARK: - 执行 Shell 脚本
    private func executeShellScript(script: String) async throws -> String {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", script]
        
        // 设置输出管道
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // 启动进程
        process.launch()
        
        // 等待进程结束
        process.waitUntilExit()
        
        // 读取输出
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ShellScriptError.outputDecodingFailed
        }
        
        // 检查执行结果
        if process.terminationStatus != 0 {
            throw ShellScriptError.scriptExecutionFailed(exitCode: process.terminationStatus, output: output)
        }
        
        return output
    }
}

enum ShellScriptError: Error {
    case appNameNotFound
    case extensionNameMissing
    case directoryChangeFailed(path: String, error: Error)
    case scriptFileReadFailed(path: String, error: Error)
    case scriptNotFound
    case outputDecodingFailed
    case scriptExecutionFailed(exitCode: Int32, output: String)
}
