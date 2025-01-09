//
//  Language.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI
import Combine

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    private let logger = Logger.shared
    
    // 可用语言列表
    private let availableLocalizations = Bundle.main.localizations
    private var languageCode: String
    
    // 本地定义的语言代码到全称的映射表
    let languageMap: [String: String] = [
        "en": "English",
        "zh": "简体中文",
        "zh-Hans": "简体中文",
    ]
    
    let language2Code: [String: String] = [
        "简体中文": "zh",
        "English": "en"
    ]
    
    // 当前选中的语言名称，默认值是系统语言名称
    @Published var selectedLanguage: String {
        didSet {
            logger.log("changelanguage to : %{public}@", selectedLanguage, type: .info)
            // 当语言更改时，通知系统刷新语言
            if let newCode = language2Code[selectedLanguage] {
                languageCode = newCode
                saveLanguageSelection()
                notifyLanguageChange()
            }
        }
    }
    
    private init() {
        // 初始化从 UserDefaults 加载语言
        let savedLanguageCode = UserDefaults.standard.string(forKey: "selectedLanguageCode")
                            ?? Locale.current.language.languageCode?.identifier
                            ?? "en"
        
        self.languageCode = savedLanguageCode
        // 转换为语言全称
        self.selectedLanguage = languageMap[savedLanguageCode] ?? "Unknown"
    }

    func getAvailableLanguages() -> [String] {
        // 使用字典映射语言代码到语言全称
        return availableLocalizations.compactMap { languageMap[$0] }
    }

    // 获取当前语言名称
    func getCurrentLanguage() -> String {
        return selectedLanguage
    }

    // 设置语言
    func setLanguage(to languageName: String) {
        guard let newCode = language2Code[languageName],
              availableLocalizations.contains(newCode) else { return }
        selectedLanguage = languageName
    }

    // 保存语言选择
    private func saveLanguageSelection() {
        UserDefaults.standard.set(languageCode, forKey: "selectedLanguageCode")
        UserDefaults.standard.set(languageMap[languageCode], forKey: "selectedLanguage")
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    private func notifyLanguageChange() {
        // 需要在这里实现语言刷新逻辑
    }
}
