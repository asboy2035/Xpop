//
//  LanguageDetector.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Foundation
import NaturalLanguage

class LanguageDetector {
    // 单例模式（可选，方便全局使用）
    static let shared = LanguageDetector()

    // 语言代码和语言名称的映射表
    private let languageMap: [String: String] = [
        "en": "English",
        "zh-Hans": "Simplified Chinese",
        "zh-Hant": "Traditional Chinese",
        "es": "Spanish",
        "ja": "Japanese",
        "fr": "French",
        "de": "German",
        "ko": "Korean",
        "ru": "Russian",
        "it": "Italian",
        "pt": "Portuguese",
        "ar": "Arabic",
        "hi": "Hindi",
        // 可根据需要扩展更多语言
    ]

    // 最大字符长度（用于长文本截取）
    private let maxTextLength = 500

    private init() {} // 私有化初始化，防止外部创建实例

    /// 截取文本至指定长度
    /// - Parameters:
    ///   - text: 输入的文本
    ///   - maxLength: 最大长度（默认值为类内部配置）
    /// - Returns: 截取后的文本
    private func truncateText(_ text: String, maxLength: Int? = nil) -> String {
        let length = maxLength ?? maxTextLength
        return String(text.prefix(length))
    }

    /// 检测单个字符串的语言
    /// - Parameter text: 输入的字符串
    /// - Returns: 检测结果（语言代码和对应语言名称），如果无法识别则返回 nil
    func detectLanguage(for text: String) -> (languageCode: String, languageName: String)? {
        let truncatedText = truncateText(text)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(truncatedText)

        if let dominantLanguage = recognizer.dominantLanguage?.rawValue {
            let languageName = languageMap[dominantLanguage] ?? "Unknown Language"
            return (dominantLanguage, languageName)
        }
        return nil
    }

    /// 批量检测多个字符串的语言
    /// - Parameter texts: 输入的字符串数组
    /// - Returns: 检测结果数组，每个元素包含原始文本、语言代码和语言名称
    func detectLanguages(for texts: [String]) -> [(text: String, languageCode: String, languageName: String)] {
        texts.compactMap { text in
            if let result = detectLanguage(for: text) {
                return (text, result.languageCode, result.languageName)
            }
            return nil
        }
    }

    /// 批量检测多个字符串的语言（并行处理）
    /// - Parameter texts: 输入的字符串数组
    /// - Returns: 检测结果数组，每个元素包含原始文本、语言代码和语言名称
    func detectLanguagesInParallel(for texts: [String]) -> [(
        text: String,
        languageCode: String,
        languageName: String
    )] {
        let queue = DispatchQueue(label: "languageDetectionQueue", attributes: .concurrent)
        let group = DispatchGroup()
        var results: [(String, String, String)] = []
        let resultsLock = NSLock() // 确保线程安全

        for text in texts {
            queue.async(group: group) {
                if let result = self.detectLanguage(for: text) {
                    resultsLock.lock()
                    results.append((text, result.languageCode, result.languageName))
                    resultsLock.unlock()
                }
            }
        }

        group.wait() // 等待所有任务完成
        return results
    }
}
