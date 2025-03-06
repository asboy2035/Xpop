//
//  TransPanelViewController.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Cocoa
import Combine
import SwiftUI

class TransPanelViewController: NSViewController {
    private var mousePositionLabel: NSTextField!
    private var toggleTopButton: ToggleTopButton! // 置顶按钮
    private var timer: Timer?
    private var chatResult: String = ""
    @Published var query: String = ""
    // 监控按钮语言选择的变化
    private var languageState = LanguageSelectionState()
    private var cancellables: Set<AnyCancellable> = []
    private var isInitialTrigger = true
    private var srcLang = ""

    private var scrollableTextView: ScrollableTextView!
    // 添加一个高度约束的属性
    private var heightConstraint: NSLayoutConstraint!

    // streaming
    private var streamBuffer: [String] = [] // 缓冲区保存流式接口接收到的内容
    private var isTyping: Bool = false // 标记是否正在进行打字机输出
    private var typingTimer: Timer?
    private var currentTypingSpeed: TimeInterval = 0.05 // 默认打字速度
    private let typingSpeedMin: TimeInterval = 0.01 // 最小速度
    private let typingSpeedMax: TimeInterval = 0.2 // 最大速度
    private var currentTask: Task<Void, Never>?

    private let logger = Logger.shared

    // 自定义初始化方法
    init(query: String) {
        self.query = query
        super.init(nibName: nil, bundle: nil)
        detectSrcLang()
    }

    // 必须实现的初始化器
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.frame.size = NSSize(width: 400, height: 256)
        // 设置最大高度约束
        let maxHeightConstraint = view.heightAnchor.constraint(lessThanOrEqualToConstant: 600)
        maxHeightConstraint.isActive = true

        // 设置初始高度约束
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 256)
        heightConstraint.isActive = true

        // 启用主视图的图层支持
        view.wantsLayer = true
        view.layer?.cornerRadius = 10 // 设置圆角半径
        view.layer?.masksToBounds = true // 裁剪超出边界的内容

        // 设置毛玻璃效果
        let visualEffectView = NSVisualEffectView(frame: view.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .withinWindow // .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .popover // .sidebar // 可根据需要选择不同的材质
        view.addSubview(visualEffectView)

        // 初始化按钮并设置回调
        toggleTopButton = ToggleTopButton()
        toggleTopButton.onToggle = { [weak self] in
            guard let self = self, let panel = self.view.window as? TransPanel else { return }
            panel.isAlwaysOnTop.toggle()
            self.toggleTopButton.image = panel.isAlwaysOnTop ?
                NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pin") :
                NSImage(systemSymbolName: "pin", accessibilityDescription: "Unpin")
        }

        visualEffectView.addSubview(toggleTopButton)

        // 翻译图标
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "translate", accessibilityDescription: "Translate")
        iconView.imageScaling = .scaleProportionallyUpOrDown // 按比例缩放
        iconView.contentTintColor = NSColor.labelColor // 设置图标颜色
        visualEffectView.addSubview(iconView)

        // 翻译文字说明
        let descriptionLabel = NSTextField(labelWithString: "Translation")
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = NSFont.systemFont(ofSize: 14) // 设置字体大小
//        descriptionLabel.textColor = NSColor(deviceWhite: 0.8, alpha: 1.0) // 设置文本颜色
        descriptionLabel.textColor = NSColor.labelColor
        descriptionLabel.alignment = .center // 文本居中对齐
        descriptionLabel.lineBreakMode = .byWordWrapping // 支持换行
        visualEffectView.addSubview(descriptionLabel)

        // 添加分割线
        let separator = NSBox()
        separator.boxType = .separator // 设置为分割线类型
        separator.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(separator)

        // 初始化 CopyButton
        let copyButton = CopyButton()
        copyButton.onCopy = {
            self.logger.log("copy button clicked.", type: .debug)
            // 在这里添加具体的复制逻辑，比如将某些文本复制到剪贴板
            let content = self.scrollableTextView.getTextContent()
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
        }
        visualEffectView.addSubview(copyButton)

        // 初始化RegenerateButton
        let regenerateButton = RegenerateButton()
        regenerateButton.onRegenerate = {
            self.logger.log("regenerate button clicked.", type: .debug)
            self.updateTranslationWithStream(query: self.query)
        }
        visualEffectView.addSubview(regenerateButton)

        // 源语言按钮
        let srcLangButton = DropdownLangButton(items: ["简体中文", "English", "繁体中文"]) { selectedItem in
            self.logger.log("source language select: %{public}@", selectedItem, type: .debug)
            self.languageState.sourceLanguage = selectedItem
        }
        visualEffectView.addSubview(srcLangButton)

        // 目标语言按钮
        let tgtLangButton = DropdownLangButton(
            title: LanguageSelectionState().targetLanguage,
            items: ["简体中文", "English", "繁体中文"]
        ) { selectedItem in
            self.logger.log("target language select: %{public}@", selectedItem, type: .debug)
            UserDefaults.standard.set(selectedItem, forKey: "transTargetLanguage")
            self.languageState.targetLanguage = selectedItem
        }
        visualEffectView.addSubview(tgtLangButton)

        // 监听语言状态变化
        languageState.$sourceLanguage
            .combineLatest(languageState.$targetLanguage)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 加入防抖机制
            .sink { [weak self] source, target in
                guard let self = self else { return }

                // 判断是否是初始化触发
                if self.isInitialTrigger {
                    self.isInitialTrigger = false
                    return
                }

                // 打印调试信息
                self.logger.log(
                    "source language: %{public}@, target language: %{public}@",
                    source,
                    target,
                    type: .debug
                )

                // 如果 query 非空，调用更新翻译
                if !self.query.isEmpty {
                    self.updateTranslationWithStream(query: self.query)
                } else {
                    self.logger.log("Query is empty", type: .info)
                }
            }
            .store(in: &cancellables)

        // 添加向右箭头图标
        let arrowRightIcon = NSImageView()
        arrowRightIcon.translatesAutoresizingMaskIntoConstraints = false
        arrowRightIcon.image = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: "Arrow Right")
        arrowRightIcon.contentTintColor = .gray // 设置图标颜色
        visualEffectView.addSubview(arrowRightIcon)

        // 初始化滚动文本视图
        scrollableTextView = ScrollableTextView()
        scrollableTextView.translatesAutoresizingMaskIntoConstraints = false // 使用 Auto Layout
        // 监听 scrollableTextView 的高度变化
        scrollableTextView.onHeightChange = { [weak self] newHeight in
            guard let self = self else { return }
            let totalHeight = newHeight + 144 // 顶部间距50 + 底部间距40
            self.heightConstraint.animator().constant = totalHeight // 动画更新高度
        }
        visualEffectView.addSubview(scrollableTextView)

        NSLayoutConstraint.activate([
            // 翻译图标
            iconView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 5), // 距离顶部
            iconView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 10), // 距离左侧
            iconView.widthAnchor.constraint(equalToConstant: 32), // 图标宽度
            iconView.heightAnchor.constraint(equalToConstant: 32), // 图标高度
            // 翻译文本说明
            descriptionLabel.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 13),
            descriptionLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 40),
            // 距离左侧 10 点
            // 置顶按钮
            toggleTopButton.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 15), // 距离顶部 10 点
            toggleTopButton.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -10),
            // 距离右侧 10 点
            toggleTopButton.widthAnchor.constraint(equalToConstant: 28), // 这个pin的图标在垂直方向上的长度比较大。
            toggleTopButton.heightAnchor.constraint(equalToConstant: 20),
            // 分割线
            separator.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 10), // 左侧对齐
            separator.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -10), // 右侧对齐
            separator.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 45), // 位于图标下方

            // 复制按钮
            copyButton.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -10), // 距离底部
            copyButton.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 10), // 距离左侧
            copyButton.widthAnchor.constraint(equalToConstant: 55), // 图标宽度
            copyButton.heightAnchor.constraint(equalToConstant: 28), // 图标高度

            // 重新生成按钮
            regenerateButton.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -10), // 距离底部
            regenerateButton.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 70), // 距离左侧
            regenerateButton.widthAnchor.constraint(equalToConstant: 80), // 图标宽度
            regenerateButton.heightAnchor.constraint(equalToConstant: 28), // 图标高度

            // 源语言按钮
            srcLangButton.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            srcLangButton.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 10),
            srcLangButton.widthAnchor.constraint(equalToConstant: 150),
            srcLangButton.heightAnchor.constraint(equalToConstant: 30),

            // target语言按钮
            tgtLangButton.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            tgtLangButton.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -10),
            tgtLangButton.widthAnchor.constraint(equalToConstant: 150),
            tgtLangButton.heightAnchor.constraint(equalToConstant: 30),

            // 向右箭头图标
            arrowRightIcon.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            arrowRightIcon.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor), // 垂直居中
            arrowRightIcon.widthAnchor.constraint(equalToConstant: 36), // 图标宽度
            arrowRightIcon.heightAnchor.constraint(equalToConstant: 36), // 图标高度

            // 文本显示
            scrollableTextView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 95),
            scrollableTextView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 10),
            scrollableTextView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -10),
            scrollableTextView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -45),
        ])

        bindQueryToUpdate()
    }

    public func setQuery(query: String) {
        self.query = query
    }

    // auto detect source language
    private func detectSrcLang() {
        let result = LanguageDetector.shared.detectLanguage(for: query)
        srcLang = result!.languageName
        languageState.sourceLanguage = srcLang
    }

    private func bindQueryToUpdate() {
        // 监听 query 的变化
        $query
            .removeDuplicates() // 避免重复相同的值触发
            .sink { [weak self] newQuery in
                guard let self = self, !newQuery.isEmpty else { return }
                updateTranslationWithStream(query: newQuery)
            }
            .store(in: &cancellables)
    }

    private func updateTranslation(query: String) {
        let source = languageState.sourceLanguage
        let target = languageState.targetLanguage

        // 调用翻译函数
        Task { [weak self] in
            guard let self = self else { return }
            self.chatResult = await self.getTranslateResult(source: source, target: target, query: query)

            // 更新 TextView 显示结果
            DispatchQueue.main.async {
                self.scrollableTextView.setTextWithTypingEffect(self.chatResult)
            }
        }
    }

    private func updateTranslationWithStream(query: String) {
        let source = languageState.sourceLanguage
        let target = languageState.targetLanguage

        // 如果有正在运行的任务，取消它
        currentTask?.cancel()
        // 立即将 currentTask 设置为 nil，以确保不会有其他代码引用旧的任务
        currentTask = nil

        currentTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                // 切换到主线程开始任务
                await MainActor.run {
                    self.streamBuffer.removeAll()
                    self.scrollableTextView.setText("")
                    self.scrollableTextView.stopTypingEffect()
                }

                let stream = try await self.getTranslateResultStream(source: source, target: target, query: query)
                for await chunk in stream {
                    // 检查任务是否已取消
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.streamBuffer.append(chunk)
                        self.scrollableTextView.setTextWithTypingEffectStream(streamBuffer: [chunk])
                    }
                }
            } catch {
                // 处理错误或取消
                if Task.isCancelled {
                    self.streamBuffer.removeAll()
                    self.scrollableTextView.setText("")
                    self.scrollableTextView.stopTypingEffect()
                } else {
//                    self.scrollableTextView.setText(error.localizedDescription)
                    logger.log("Streaming translation failed: %{public}@", error.localizedDescription, type: .error)
                }
            }
        }
    }

    private func startTypingEffectIfNeeded() {
        guard !isTyping else { return }
        isTyping = true

        typingTimer = Timer.scheduledTimer(withTimeInterval: currentTypingSpeed, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // 动态调整打字速度
            self.adjustTypingSpeed()

            if self.streamBuffer.isEmpty {
                // 如果缓冲区为空，暂停打字效果
                self.isTyping = false
                timer.invalidate()
            } else {
                // 从缓冲区中取出一部分内容
                let nextChunk = self.streamBuffer.removeFirst()
                let currentText = self.scrollableTextView.getTextContent()
                self.scrollableTextView.setText(currentText + nextChunk)
            }
        }
    }

    private func adjustTypingSpeed() {
        let bufferLength = streamBuffer.count
        // 根据缓冲区大小动态调整速度
        if bufferLength > 10 {
            currentTypingSpeed = max(typingSpeedMin, currentTypingSpeed - 0.01)
        } else if bufferLength < 3 {
            currentTypingSpeed = min(typingSpeedMax, currentTypingSpeed + 0.01)
        }
    }

    private func getTranslateResult(source: String, target: String, query: String) async -> String {
        let client = OpenAIChatClient()
        let systemPrompt = "你是一位专业的翻译。请将用户输入的文本由 \(source) 翻译成 \(target)，保持原文的语气和风格。"
        let messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: query),
        ]
        logger.log("Start streaming chat...")
        do {
            let response = try await client.fetchChatCompletion(messages: messages)
            return response
        } catch {
            logger.log("Translation failed: %{public}@", error.localizedDescription, type: .error)
            return "翻译失败，请稍后重试。"
        }
    }

    private func getTranslateResultStream(source: String, target: String,
                                          query: String) async throws -> AsyncStream<String> {
        let client = OpenAIChatClient()
        let systemPrompt = "你是一位专业的翻译。请将用户输入的文本由 \(source) 翻译成 \(target)，保持原文的语气和风格。"
        let messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: query),
        ]
        return try await client.streamChatCompletion(messages: messages)
    }

    deinit {
        timer?.invalidate()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = view.window else { return }
        window.performDrag(with: event)
    }

    @objc private func toggleTop() {
        guard let panel = view.window as? TransPanel else { return }
        panel.isAlwaysOnTop.toggle() // 切换置顶状态
        toggleTopButton.image = panel.isAlwaysOnTop ?
            NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pin") : // 置顶图标
            NSImage(systemSymbolName: "pin", accessibilityDescription: "Unpin") // 取消置顶图标
    }
}

class ToggleTopButton: NSButton {
    var onToggle: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        bezelStyle = .rounded // .regularSquare
        image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Unpin")
        target = self
        action = #selector(toggleTop)
        wantsLayer = true
        isBordered = false

        // 设置圆角和默认背景
        layer?.cornerRadius = 6 // 调整圆角半径
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor

        updateHoverEffect(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHoverEffect(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateHoverEffect(false)
    }

    @objc private func toggleTop() {
        onToggle?()
    }

    private func updateHoverEffect(_ isHovered: Bool) {
        if isHovered {
            // 设置加深的背景色和圆角
            layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
        } else {
            // 恢复为透明
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

class CopyButton: NSButton {
    var onCopy: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        bezelStyle = .rounded
        // 设置自定义 Cell和图标
        let customCell = CustomButtonCell()
        cell = customCell
        let image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")!

        let resizedImage = image.resized(to: NSSize(width: 15, height: 15)).flippedVertically() // 调整图标大小
//        self.image = image
        self.image = resizedImage
        imagePosition = .imageLeading

        // 设置富文本标题，指定颜色
        let titleString = "复制"
        let attributedTitle = NSAttributedString(
            string: titleString,
            attributes: [
                .foregroundColor: NSColor.labelColor, // NSColor(deviceWhite: 0.8, alpha: 1.0), // 浅灰色
                .font: NSFont.systemFont(ofSize: 13), // 设置字体大小
            ]
        )
        self.attributedTitle = attributedTitle // 设置富文本标题

        target = self
        action = #selector(copyAction)
        wantsLayer = true
        isBordered = false
        // 设置圆角和默认背景
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor

        updateHoverEffect(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHoverEffect(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateHoverEffect(false)
    }

    @objc private func copyAction() {
        onCopy?()
    }

    private func updateHoverEffect(_ isHovered: Bool) {
        if isHovered {
            layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

class RegenerateButton: NSButton {
    var onRegenerate: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        bezelStyle = .rounded
        // 设置自定义 Cell和图标
        let customCell = CustomButtonCell()
        cell = customCell
        let image = NSImage(
            systemSymbolName: "arrow.trianglehead.2.clockwise.rotate.90",
            accessibilityDescription: "Copy"
        )!
        let resizedImage = image.resized(to: NSSize(width: 15, height: 15)) // 调整图标大小
        self.image = resizedImage
        imagePosition = .imageLeading

        // 设置富文本标题，指定颜色
        let titleString = "重新生成"
        let attributedTitle = NSAttributedString(
            string: titleString,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13), // 设置字体大小
            ]
        )
        self.attributedTitle = attributedTitle // 设置富文本标题

        target = self
        action = #selector(regenerateAction)
        wantsLayer = true
        isBordered = false
        // 设置圆角和默认背景
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor

        updateHoverEffect(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHoverEffect(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateHoverEffect(false)
    }

    @objc private func regenerateAction() {
        updateHoverEffect(false)
        onRegenerate?()
    }

    private func updateHoverEffect(_ isHovered: Bool) {
        if isHovered {
            layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    // 返回沿垂直轴翻转后的图像
    func flippedVertically() -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()

        // 设置变换：垂直轴对称
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: size.height) // 垂直方向移动到顶边界
        transform.scaleX(by: 1.0, yBy: -1.0) // 垂直方向翻转
        transform.concat()

        // 绘制原始图像到新的上下文中
        draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }
}

class CustomButtonCell: NSButtonCell {
    var imageOffset: CGFloat // 图片向右偏移的像素数

    init(imageOffset: CGFloat = 5) { // 默认偏移为 5
        self.imageOffset = imageOffset
        super.init(textCell: "") // 调用 NSButtonCell 的指定初始化器
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawImage(_ image: NSImage, withFrame frame: NSRect, in _: NSView) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()

        // 偏移图片位置
        let adjustedFrame = frame.offsetBy(dx: imageOffset, dy: 0) // 应用偏移

        // 设置剪裁区域
        context.addRect(adjustedFrame)
        context.clip()

        // 绘制图片
        image.draw(in: adjustedFrame, from: .zero, operation: .sourceOver, fraction: 1.0)

        // 设置渲染颜色为白色
        context.setBlendMode(.sourceIn) // 只保留图片的形状
        context.setFillColor(NSColor.labelColor.cgColor)
        context.fill(adjustedFrame) // 应用填充

        context.restoreGState()
    }
}

class DropdownLangButton: NSButton {
    private var dropdownMenu: NSMenu! // 避免与 NSButton 的 menu 属性冲突
    let imageOffset: CGFloat = -10

    private var onSelect: ((String) -> Void)?

    init(title: String = "自动检测", items: [String], onSelect: @escaping (String) -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        bezelStyle = .rounded

        let customCell = CustomButtonCell(imageOffset: imageOffset)
        cell = customCell
        let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Dropdown")!.flippedVertically()
        self.image = image
        self.title = title

        imagePosition = .imageTrailing
        wantsLayer = true
        isBordered = false

        // 设置按钮圆角和背景
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.1).cgColor

        // 初始化菜单
        dropdownMenu = NSMenu()
        for item in items {
            let menuItem = NSMenuItem(title: item, action: #selector(selectItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
            dropdownMenu.addItem(menuItem)
        }

        // 保存选择回调
        self.onSelect = onSelect
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? String else { return }
        title = item // 更新按钮标题
        onSelect?(item) // 调用选择回调
    }

    override func mouseDown(with _: NSEvent) {
        guard let superview = superview else { return }

        // 调整菜单宽度以匹配按钮宽度
        adjustMenuWidth()
        // 计算菜单的位置：按钮的左下角
        let buttonFrame = frame
        let menuOrigin = CGPoint(x: buttonFrame.minX, y: buttonFrame.minY - 10)

        // 弹出菜单
        dropdownMenu.popUp(positioning: nil, at: menuOrigin, in: superview)
    }

    private func adjustMenuWidth() {
        // 获取按钮的宽度
        let buttonWidth = frame.width

        // 设置菜单的最小宽度
        dropdownMenu.minimumWidth = buttonWidth

        // 更新每个菜单项的文本属性
        for menuItem in dropdownMenu.items {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = NSTextAlignment.left // 明确指定对齐方式

            menuItem.attributedTitle = NSAttributedString(
                string: menuItem.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .paragraphStyle: paragraphStyle,
                ]
            )
        }
    }
}

class ScrollableTextView: NSView {
    // 翻转视图的坐标系统
    override var isFlipped: Bool {
        true
    }

    private let scrollView: NSScrollView
    private let textView: NSTextView
    private let maxHeight: CGFloat = 456

    private var typingTimer: Timer?
    private var fullText: String = ""
    private var currentIndex: Int = 0

    var onHeightChange: ((CGFloat) -> Void)? // 高度变化的回调

    // streaming
    private var currentText: String = "" // 当前显示的文本内容
    private var isTyping: Bool = false // 标记是否正在进行打字效果
    private let typingSpeedMin: TimeInterval = 0.01 // 最小速度
    private let typingSpeedMax: TimeInterval = 0.2 // 最大速度
    private var currentTypingSpeed: TimeInterval = 0.01 // 当前打字速度
    // 新增一个缓冲区属性
    private var internalStreamBuffer: [String] = []

    override init(frame frameRect: NSRect) {
        // 初始化滚动视图，初始高度设为0，后续根据内容调整
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: frameRect.width, height: 0))
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        // 创建文本存储、布局管理器和文本容器
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(
            width: frameRect.width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        // 初始化文本视图
        textView = NSTextView(frame: NSRect(origin: .zero, size: frameRect.size),
                              textContainer: textContainer)

        // 配置文本视图
        textView.minSize = NSSize(width: 0.0, height: 0.0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = NSColor.labelColor
        textView.font = NSFont.systemFont(ofSize: 14)

        // 设置自动布局
        textView.autoresizingMask = [.width]
        textContainer.containerSize = NSSize(
            width: frameRect.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textContainer.widthTracksTextView = true

        // 设置滚动视图的文档视图
        scrollView.documentView = textView

        super.init(frame: frameRect)

        // 添加滚动视图到父视图
        addSubview(scrollView)

        // 设置滚动视图的自动调整
        scrollView.autoresizingMask = [.width]

        // 监听 NSTextView 内容变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func textDidChange(_: Notification) {
        adjustHeight()
    }

    private func adjustHeight() {
        // 计算文本内容所需的高度
        let textHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
        let desiredHeight = ceil(textHeight)

        // 判断是否需要启用滚动
        if desiredHeight <= maxHeight {
            // 不需要滚动，调整滚动视图和文本视图的高度
            scrollView.hasVerticalScroller = false
            scrollView.frame.size.height = max(desiredHeight, 112.0)
            textView.frame.size.height = max(desiredHeight, 112.0)
            onHeightChange?(max(desiredHeight, 112.0))
        } else {
            // 需要滚动，设置滚动视图和文本视图的高度为最大高度
            scrollView.hasVerticalScroller = true
            scrollView.frame.size.height = maxHeight
            textView.frame.size.height = desiredHeight
            onHeightChange?(maxHeight)
        }

        // 确保 textView 的 origin 固定
        textView.frame.origin = .zero

        // 通知布局更新
        needsLayout = true
    }

    func setText(_ text: String) {
        stopTypingEffect() // 停止任何打字机效果

        // 设置文本内容
        textView.string = text
        currentText = text

        // 更新布局
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        adjustHeight()
    }

    override func layout() {
        super.layout()
        // 保持滚动视图的宽度与父视图一致
        scrollView.frame.size.width = bounds.width
        textView.frame.size.width = bounds.width

        // 确保 textView 的 origin 固定
        textView.frame.origin = .zero

        // 重新调整高度
        adjustHeight()
    }

    func stopTypingEffect() {
        isTyping = false
        typingTimer?.invalidate()
        typingTimer = nil
        currentIndex = 0
        currentText = ""
        currentTypingSpeed = 0.01 // 当前打字速度
        internalStreamBuffer.removeAll()
    }

    func setTextWithTypingEffect(_ text: String, typingSpeed: TimeInterval = 0.05) {
        stopTypingEffect()
        fullText = text
        currentIndex = 0
        textView.string = ""

        typingTimer = Timer.scheduledTimer(withTimeInterval: typingSpeed, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if self.currentIndex < self.fullText.count {
                let nextIndex = self.fullText.index(self.fullText.startIndex, offsetBy: self.currentIndex + 1)
                let substring = String(self.fullText[..<nextIndex])
                self.textView.string = substring
                self.currentIndex += 1

                // 不需要滚动到末尾，因为视图高度在增加
                self.textView.scrollToEndOfDocument(nil)

                // 调整高度
                self.adjustHeight()
            } else {
                timer.invalidate()
            }
        }
    }

    func setTextWithTypingEffectStream(streamBuffer: [String]) {
        // 将传入的缓冲区内容追加到内部缓冲区
        internalStreamBuffer.append(contentsOf: streamBuffer)
        if isTyping {
            return
        }
        // 启动打字机效果
        isTyping = true
        typingTimer = Timer.scheduledTimer(withTimeInterval: currentTypingSpeed, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // 根据缓冲区大小动态调整速度
            let bufferLength = self.internalStreamBuffer.count
//            if bufferLength > 10 {
//                currentTypingSpeed = max(typingSpeedMin, currentTypingSpeed - 0.01)
//            } else if bufferLength < 3 {
//                currentTypingSpeed = min(typingSpeedMax, currentTypingSpeed + 0.01)
//            }
            if self.internalStreamBuffer.isEmpty, self.currentText == self.textView.string {
                // 停止计时器
                self.isTyping = false
                timer.invalidate()
                return
            }

            // 动态检查缓冲区是否有新的内容
            if !self.internalStreamBuffer.isEmpty {
                let nextChunk = self.internalStreamBuffer.removeFirst()
                self.currentText += nextChunk
                self.textView.string = self.currentText

                // 自动滚动到末尾
                self.textView.scrollToEndOfDocument(nil)

                // 调整高度
                self.adjustHeight()
            }
        }
    }

    public func getTextContent() -> String {
        let result = textView.string
        return result
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

class LanguageSelectionState: ObservableObject {
    @Published var sourceLanguage: String = "简体中文"
    @Published var targetLanguage: String = UserDefaults.standard.string(forKey: "transTargetLanguage") ?? "English"
}
