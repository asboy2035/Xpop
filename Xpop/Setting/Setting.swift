//
//  Setting.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject var manager: ProviderManager // 自动获取注入的实例
   
    
    @State var chosenProviderId: String = UserDefaults.standard.string(forKey: "chosenProviderId") ?? ""
    @State var chosenProviderName: String = UserDefaults.standard.string(forKey: "chosenProviderName") ?? ""
    @State var chosenModels: [String] = UserDefaults.standard.stringArray(forKey: "chosenModels") ?? [""]
    @State var chosenModel: String = UserDefaults.standard.string(forKey: "chosenModel") ?? ""
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var settingManager = SettingsManager.shared
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    let avaliableLanguage = languageManager.getAvailableLanguages()
                    SettingsPickerRow(title: String(localized: "Language"), options: avaliableLanguage, chosenOption: $languageManager.selectedLanguage)
                    
                    NavigationLink(destination: ManageForbiddenAppView()){
                        SettingsRow(title: String(localized: "Forbidden Apps"), detail: "")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(Color(NSColor.labelColor))
                    
                    SettingsToggleRow(title: "Enable Force Select Text", isOn: true)
                } header: {
                    Text("General")
                }
                
                Section {
                    let selections: [String: String] = Dictionary(uniqueKeysWithValues: manager.providers.map { ($0.id, $0.name) })
                    SettingsModelProviderRow(title: String(localized: "Provider"), selections: selections, selectedId: $chosenProviderId, selectedProvider: $chosenProviderName, selectedModels: $chosenModels, selectedModel: $chosenModel)
                    SettingsPickerRow(title: String(localized: "Model Name"), options: chosenModels, chosenOption: $chosenModel)
                    
                    NavigationLink(destination: ManageModelView()){
                        SettingsRow(title: String(localized: "Manage..."), detail: "")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(Color(NSColor.labelColor))
                } header: {
                    Text("Model")
                }
                
                Section {
                    NavigationLink(destination: ExtensionManagerView()){
                        SettingsRow(title: String(localized: "Extension..."), detail: "")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(Color(NSColor.labelColor))
                } header: {
                    Text("Extensions")
                }
                
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "Settings"))
        }
        .onChange(of: chosenProviderId) {
            UserDefaults.standard.set(chosenProviderId, forKey: "chosenProviderId")
        }
        .onChange(of: chosenProviderName) {
            UserDefaults.standard.set(chosenProviderName, forKey: "chosenProviderName")
        }
        .onChange(of: chosenModels) {
            UserDefaults.standard.set(chosenModels, forKey: "chosenModels")
        }
        .onChange(of: chosenModel) {
            UserDefaults.standard.set(chosenModel, forKey: "chosenModel")
        }
        .onChange(of: languageManager.selectedLanguage){
            UserDefaults.standard.set(languageManager.selectedLanguage, forKey: "selectedLanguage")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { // Removed spacing to align rows tightly
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.leading, 8)  //设置左侧内边距为 8
            VStack(spacing: 0) { // Inner VStack for rows
                content
            }
            .background(Color.gray.opacity(0.05)) // Slightly darker background
            .cornerRadius(4)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal)
    }
}

struct SettingsRow: View {
    let title: String
    let detail: String
    var isToggle: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    @State var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
        }
    }
}

struct SettingsModelProviderRow: View {
    let title: String
    @EnvironmentObject var manager: ProviderManager // 自动获取注入的实例
    var selections: [String: String]
    @Binding var selectedId: String
    @Binding var selectedProvider: String
    @Binding var selectedModels: [String]
    @Binding var selectedModel: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            // 下拉菜单
            Picker("", selection: $selectedId) {
                ForEach(Array(selections.keys), id: \.self) { key in
                    Text(selections[key]!).tag(key)
                }
            }
            .pickerStyle(MenuPickerStyle()) // 使用下拉菜单样式
            .frame(width: 150) // 调整宽度
            .onChange(of: selectedId) { newValue in
                // 当 selectedId 改变时更新 selectedProvider
                selectedProvider = selections[newValue] ?? ""
                selectedModels = manager.getProvider(by: newValue)!.supportedModels
                selectedModel = selectedModels[0]
            }
        }
    }
}

struct SettingsModelRow: View {
    let title: String
    var selections: [String]
    @Binding var selectedModel: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            // 下拉菜单
            Picker("", selection: $selectedModel) {
                ForEach(selections, id: \.self) { selection in
                    Text(selection).tag(selection)
                }
            }
            .pickerStyle(MenuPickerStyle()) // 使用下拉菜单样式
            .frame(width: 150) // 调整宽度
        }
        .onAppear {
            // 设置初始值为列表的第一个值
            if selectedModel.isEmpty, let firstValue = selections.first {
                selectedModel = firstValue
            }
        }
    }
}

struct SettingsPickerRow: View {
    let title: String
    let options: [String]
    @Binding var chosenOption: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Picker("", selection: $chosenOption) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 150)
        }
    }
}

struct SettingLanguageRow: View {
    let title: String
    let supportLanguage: [String]
    @Binding var chosenLanguage: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            // 下拉菜单
            Picker("", selection: $chosenLanguage) {
                ForEach(supportLanguage, id: \.self) { language in
                    Text(language)
                        .tag(language)
                }
            }
            .pickerStyle(MenuPickerStyle()) // 使用下拉菜单样式
            .frame(width: 150) // 调整宽度
        }
        .onAppear {
            // 设置初始值为列表的第一个值
            if supportLanguage.isEmpty, let firstValue = supportLanguage.first {
                chosenLanguage = firstValue
            }
        }
    }
}

struct SettingModeRow: View {
    let title: String
    let supportValue: [String]
    @Binding var chosenMode: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            // 下拉菜单
            Picker("", selection: $chosenMode) {
                ForEach(supportValue, id: \.self) { mode in
                    Text(mode).tag(mode)
                    
                }
            }
            .pickerStyle(MenuPickerStyle()) // 使用下拉菜单样式
            .frame(width: 150) // 调整宽度
        }
        .onAppear {
            // 设置初始值为列表的第一个值
            if supportValue.isEmpty, let firstValue = supportValue.first {
                chosenMode = firstValue
            }
        }
        .padding()
        .frame(height: 40) // 设置固定高度，例如 40
    }
}

struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 0) // 保持按钮原始大小
            .background(
                // 创建一个带有额外范围的背景
                configuration.isPressed
                    ? Color(NSColor(calibratedWhite: 0.8, alpha: 1.0))
                        .padding(.vertical, -1) // 向上和向下拓展10点
                    : Color.clear
                        .padding(.vertical, 10)
            )
            .contentShape(Rectangle()) // 保证可点击区域为矩形
    }
}

//#Preview {
//    SettingView()
//}
