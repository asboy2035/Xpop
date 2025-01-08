//
//  ManageProvider.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Foundation

// 模型供应商及相关信息
struct ModelProvider: Codable {
    let id: String               // 唯一标识供应商
    var name: String             // 供应商名称
    var baseURL: String          // 供应商的 Base URL
    var apiKey: String           // API Key（加密存储推荐）
    var supportedModels: [String] // 支持的模型类型
}

enum ModelProviderError: Error {
    case emptyModelsName
    case invalidModelsName(String) // 包含具体的错误信息
}

func createModelProvider(providerName: String, baseURL: String, apiKey: String, modelsName: String) throws -> ModelProvider {
    // 处理用户输入的 modelsName，解析可能会抛出错误
    let supportedModels = try parseModelsName(modelsName)
    
    // 创建 ModelProvider 实例
    return ModelProvider(
        id: UUID().uuidString, // 生成唯一 ID
        name: providerName,
        baseURL: baseURL,
        apiKey: apiKey,
        supportedModels: supportedModels
    )
}

func parseModelsName(_ modelsName: String) throws -> [String] {
    // 检查是否为空或仅包含空格
    if modelsName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw ModelProviderError.emptyModelsName
    }
    
    // 分割字符串并清理多余空格
    let modelsList = modelsName
        .split(separator: ";") // 按分号分割
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } // 去除空格和换行
        .filter { !$0.isEmpty } // 排除空字符串
    
    // 如果解析后仍然为空，抛出错误
    if modelsList.isEmpty {
        throw ModelProviderError.invalidModelsName(modelsName)
    }
    
    return modelsList
}

class ProviderManager: ObservableObject {
    
    static let shared = ProviderManager() // 单例实例
    
    @Published var providers: [ModelProvider] = []  // 自动触发视图更新
    private let fileName = "Providers.json"
    private let fileManager = FileManager.default

    init() {
        loadProviders() // 初始化时加载文件数据
    }

    // 加载数据
    func loadProviders() {
        let fileURL = getFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            providers = [] // 文件不存在时，初始化为空列表
            print("the file is empty")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL) // 读取文件内容
            let decodedProviders = try JSONDecoder().decode([ModelProvider].self, from: data)
//            DispatchQueue.main.async {
                self.providers = decodedProviders // 更新 providers，触发视图更新
//            }
        } catch {
            print("Failed to load providers: \(error)")
        }
    }

    // 根据 ID 获取指定的 ModelProvider
    func getProvider(by id: String) -> ModelProvider? {
        return providers.first { $0.id == id }
    }
    
    func getAllProvider() -> [ModelProvider]? {
        return providers
    }
    
    // 添加条目
    func addProvider(provider: ModelProvider) {
        providers.append(provider) // 添加条目到内存
        saveProviders()            // 保存到文件
    }

    // 删除条目根据 ID
    func deleteProvider(by id: String) {
        // 查找符合条件的索引
        if let index = providers.firstIndex(where: { $0.id == id }) {
            providers.remove(at: index) // 从内存中移除
            saveProviders()             // 保存到文件
        } else {
            print("Provider with id \(id) not found.")
        }
    }
    
    func deleteProviders(from selectedApps: inout Set<String>) {
        // 遍历 selectedApps 中的所有 ID
        for id in selectedApps {
            // 删除对应的 Provider
            if let index = providers.firstIndex(where: { $0.id == id }) {
                providers.remove(at: index) // 从内存中移除
                print("Provider with id \(id) deleted.")
            } else {
                print("Provider with id \(id) not found.")
            }
        }
        
        // 清空 selectedApps
        selectedApps.removeAll()
        saveProviders() // 保存到文件
    }

    // 保存数据到文件
    private func saveProviders() {
        let fileURL = getFileURL()
        do {
            let data = try JSONEncoder().encode(providers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save providers: \(error)")
        }
    }
    
    func updateProvider(provider: ModelProvider, newName: String, newBaseURL: String, newApiKey: String, newModels: [String]) {
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index].name = newName
            providers[index].baseURL = newBaseURL
            providers[index].apiKey = newApiKey
            providers[index].supportedModels = newModels
            saveProviders() // 保存到文件
        }
    }

    // 获取文件路径
    private func getFileURL() -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls.first!.appendingPathComponent("MyApp")
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
        return appSupportURL.appendingPathComponent(fileName)
    }

    /// 获取当前用户选择的 ModelProvider 的 API Key 和 Base URL
    func getSelectedProviderDetails() -> (apiKey: String, baseURL: String)? {
        // 从 UserDefaults 获取已选择的 Provider ID
        let chosenProviderId = UserDefaults.standard.string(forKey: "chosenProviderId") ?? ""
        
        // 查找匹配的 ModelProvider
        guard let selectedProvider = getProvider(by: chosenProviderId) else {
            print("No provider found with id: \(chosenProviderId)")
            return nil
        }
        return (selectedProvider.apiKey, selectedProvider.baseURL)
    }
}
