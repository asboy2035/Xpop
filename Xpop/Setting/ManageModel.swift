//
//  ManageModel.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI

struct ManageModelView: View {
    @EnvironmentObject var manager: ProviderManager // 自动获取注入的实例
    @State private var showSelection = false
    @State private var selectedApps: Set<String> = []
    @State private var showingSheet = false

    var body: some View {
        VStack() {
            Text("Manage Model Providers")
                .font(.title)
                .bold()
                .padding()

            VStack(alignment: .leading, spacing: 0){
                ZStack{
                    Text("Current Model Provider")
                        .padding(.top, 10)
                        .padding(.leading, 18)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1)) // 背景方便观察效果
                        .font(.system(size: 16)) // 设置字体大小为 18
                        .foregroundColor(Color.gray)
                    if showSelection {
                        Button(action: {
                            withAnimation{
                                // Remove selected apps
                                manager.deleteProviders(from: &selectedApps)
                                selectedApps.removeAll()
                                showSelection = false
                            }
                        }) {
                            Text("Delete")
                                .bold()
                        }
                        .buttonStyle(DeleteButtonStyle())
                        .background(Color.gray.opacity(0.5)) // 背景方便观察效果
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2) // 添加阴影
                    }
                }
                
                List() {
                    ForEach(manager.providers, id: \.id) { provider in
                        ModelProviderRow(provider: provider, showSelection: $showSelection, selectedApps: $selectedApps)
                    }
                }
                .scrollContentBackground(.hidden) // 隐藏背景
            }
            .background(Color.gray.opacity(0.1)) // Slightly darker
            .cornerRadius(10)
            .padding([.leading, .trailing], 30) // 设置左右内边距为 30

            HStack {
                // "+" Button
                Button(action: {
                    showingSheet.toggle()
                }) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2)) // Adjusted background for macOS
                        .cornerRadius(5)
                }
                .sheet(isPresented: $showingSheet) {
                    AddProviderView()
                }
                .buttonStyle(BorderlessButtonStyle())

                // "-" Button
                Button(action: {
                    withAnimation{
                        showSelection.toggle()
                    }
                    if !showSelection {
                        selectedApps.removeAll() // Reset selections when canceling
                    }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2)) // Adjusted background for macOS
                        .cornerRadius(5)
                }
                .buttonStyle(BorderlessButtonStyle())
                
            }
            .padding()
        }

    }
}

struct ModelProviderRow: View {
    let provider: ModelProvider
    @Binding var showSelection: Bool
    @Binding var selectedApps: Set<String>
    @State private var showingSheet = false

    var body: some View {
        HStack {
            if showSelection {
                    Button(action: {
                        if selectedApps.contains(provider.id) {
                            selectedApps.remove(provider.id)
                        } else {
                            selectedApps.insert(provider.id)
                        }
                    }) {
                        Image(systemName: selectedApps.contains(provider.id) ? "checkmark.square.fill" : "square.fill")
                            .symbolRenderingMode(.palette) // 启用调色板渲染模式
                            .foregroundStyle(Color.white, Color.gray) // 外轮廓为灰色，填充为白色
                    }
                    .buttonStyle(.plain)
                    .background(.clear)
                    
                }
            VStack(alignment: .leading) {
                Text(provider.name)
                    .font(.headline)
                Text(provider.baseURL)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button("Edit") {
                showingSheet.toggle()
            }
            .sheet(isPresented: $showingSheet) {
                AddProviderView(existingProvider: provider)
            }
            .buttonStyle(.plain)
            .background(.clear)
        }
        .padding(.vertical, 5)
        .background(.clear)
    }
}

struct ProviderItem {
    let id: String
    let name: String
    let baseURL: String
}

struct DeleteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.clear)
            .padding(8)
            .contentShape(Rectangle()) // 保证可点击区域为矩形
    }
}

struct AddProviderView: View {
    @State private var providerName: String = "" // Provider Name
    @State private var baseURL: String = ""      // Base URL
    @State private var apiKey: String = ""       // API Key
    @State private var modelsName: String = ""   // Models' name
    @State private var isPasswordVisible: Bool = false // 控制是否显示明文
    
    @State private var providerNameError: String? = nil // 错误信息
    @State private var baseURLError: String? = nil
    @State private var apiKeyError: String? = nil
    @State private var modelsNameError: String? = nil
    
    @State private var errorMessage: String = ""
    @State private var testSuccess: Bool = false

    @EnvironmentObject var manager: ProviderManager // 自动获取注入的实例
    @Environment(\.dismiss) var dismiss // 添加 dismiss 环境变量
    
    var existingProvider: ModelProvider? // 编辑时传入的已有数据
    
    private let logger = Logger.shared
    
    init(existingProvider: ModelProvider? = nil) {
        self.existingProvider = existingProvider
        _providerName = State(initialValue: existingProvider?.name ?? "")
        _baseURL = State(initialValue: existingProvider?.baseURL ?? "")
        _apiKey = State(initialValue: existingProvider?.apiKey ?? "")
        _modelsName = State(initialValue: existingProvider?.supportedModels.joined(separator: ";") ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(existingProvider == nil ? "Add Model Provider" : "Edit Model Provider")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Provider Name Input
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Provider Name:")
                    Text("Name of the service provider.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                TextField("Enter provider name", text: $providerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if let error = providerNameError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            
            // Base URL Input
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Base URL:")
                    Text("i.e https://api.openai.com/v1")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                TextField("Enter base URL", text: $baseURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if let error = baseURLError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            
            // API Key Input
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("API Key:")
                    Text("Your API key for accessing the service.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                HStack {
                    if isPasswordVisible {
                        TextField("Enter API key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        SecureField("Enter API key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                    Button(action: {
                        // 在按钮中调用异步函数
                        Task {
                            await getModels()
                        }
                    }) {
                        Text("Test")
                    }
                }
                
                HStack {
                    if (!errorMessage.isEmpty) {
                        Text("Error:")
                            .font(.footnote)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    
                    if testSuccess {
                        Text("Success!")
                            .font(.footnote)
                            .foregroundColor(.green)
                        
                    }
                }
                
                if let error = apiKeyError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            
            // Models
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Models:")
                    Text("i.e gpt-4o;gpt-4o-mini (separate by ;)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                TextField("Input models' name", text: $modelsName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if let error = modelsNameError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Buttons: Cancel and Add
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .padding(.horizontal)
                
                Button(existingProvider == nil ? "Add" : "Save") {
                    handleAddButtonClick()
                }
                .padding(.horizontal)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: 400)
    }
    
    private func getModels() async {
        let baseURL = self.baseURL + "/models"
        let apikey = self.apiKey
        let client = OpenAIChatClient(apiKey: apikey, baseURL: baseURL)
        do {
            let data = try await client.performGetRequest()
            if String(data: data, encoding: .utf8) != nil {
                errorMessage = "" // 清除错误信息
                testSuccess = true
            }
        } catch let error as NSError {
            errorMessage = "Error (\(error.code)): \(error.localizedDescription)"
            testSuccess = false
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
            testSuccess = false
        }
    }
    

    // 校验输入字段并显示错误信息
    private func handleAddButtonClick() {
        providerNameError = providerName.isEmpty ? "Provider name cannot be empty." : nil
        baseURLError = baseURL.isEmpty ? "Base URL cannot be empty." : nil
        apiKeyError = apiKey.isEmpty ? "API Key cannot be empty." : nil
        modelsNameError = validateModelsName(modelsName)

        // 如果没有错误信息，处理成功逻辑
        if providerNameError == nil && baseURLError == nil && apiKeyError == nil && modelsNameError == nil {
            if let existingProvider = existingProvider {
                // 编辑已有数据
                manager.updateProvider(
                    provider: existingProvider,
                    newName: providerName,
                    newBaseURL: baseURL,
                    newApiKey: apiKey,
                    newModels: modelsName.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                )
                dismiss()
                logger.log("ModelProvider updated: %{public}@", existingProvider.name, type: .info)
            } else {
                do {
                    let provider = try createModelProvider(
                        providerName: providerName,
                        baseURL: baseURL,
                        apiKey: apiKey,
                        modelsName: modelsName
                    )
                    logger.log("ModelProvider created: %{public}@", provider.name, type: .info)
                    manager.addProvider(provider: provider)
                    dismiss()
                } catch ModelProviderError.emptyModelsName {
                    modelsNameError = "Models name cannot be empty."
                } catch ModelProviderError.invalidModelsName(let invalidInput) {
                    modelsNameError = "Invalid models name input: '\(invalidInput)'."
                } catch {
                    logger.log("Unexpected error:: %{public}@", error.localizedDescription, type: .error)
                }
            }
        }
    }

    // 校验 modelsName 的逻辑
    private func validateModelsName(_ modelsName: String) -> String? {
        if modelsName.isEmpty {
            return "Models name cannot be empty."
        }
        let models = modelsName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if models.contains(where: { $0.isEmpty }) {
            return "Models name must be comma-separated without empty values."
        }
        return nil
    }
}

//struct ManageAppsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ManageModelView().environmentObject(ProviderManager.shared)
//    }
//}
