//
//  Language.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Combine
import SwiftUI

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
        "简体中文": "zh-Hans",
        "English": "en",
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

    // 当前语言环境
    @Published var currentLocale: Locale = .current

    private init() {
        // 初始化从 UserDefaults 加载语言
        let savedLanguageCode = UserDefaults.standard.string(forKey: "selectedLanguageCode")
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"

        languageCode = savedLanguageCode
        // 转换为语言全称
        selectedLanguage = languageMap[savedLanguageCode] ?? "Unknown"
        // 初始化当前语言环境
        currentLocale = Locale(identifier: savedLanguageCode)
    }

    func getAvailableLanguages() -> [String] {
        // 使用字典映射语言代码到语言全称
        availableLocalizations.compactMap { languageMap[$0] }
    }

    // 获取当前语言名称
    func getCurrentLanguage() -> String {
        selectedLanguage
    }

    // 设置语言
    func setLanguage(to languageName: String) {
        guard let newCode = language2Code[languageName],
              availableLocalizations.contains(newCode) else { return }
        selectedLanguage = languageName
        // 更新语言环境
        currentLocale = Locale(identifier: newCode)
    }

    // 保存语言选择
    private func saveLanguageSelection() {
        UserDefaults.standard.set(languageCode, forKey: "selectedLanguageCode")
        UserDefaults.standard.set(languageMap[languageCode], forKey: "selectedLanguage")
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    // 通知语言更改
    private func notifyLanguageChange() {
        // 可以通过 NotificationCenter 或其他方式通知视图更新
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

// 定义语言更改通知
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}
