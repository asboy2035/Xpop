//
//  AppDelegate.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static let shared = AppDelegate()
    
    var window: NSPanel!
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    let manager = TextSelectionManager()
    let panelManager = TransPanelManager()
    var forbiddenAppIDs: Set<String>?
    var hideTimer: Timer? // Timer for hiding the window
    var lastMouseLocation: NSPoint?
    
    public let eventMonitor = MouseEventMonitor()
    var selectedText: String?
    var lastSelectedText: String?
    
    var statusBarManager: StatusBarManager!
    
    @Published var isExtension: Bool = false // 直接在 AppDelegate 中定义状态
    @Published var extensionObj: Extension?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Request accessibility permission and load forbidden apps list
        requestAccessibilityPermission()
        loadForbiddenApps()

        // 2. Set up the main window
        setupMainWindow()

        // 3. Create the status bar item and menu
        // 初始化 `StatusBarManager`，并传递 `eventMonitor`
//        statusBarManager = StatusBarManager(eventMonitor: eventMonitor)
//        statusBarManager.setupStatusBar()
        setupStatusBar(eventMonitor: eventMonitor)

        // 4. Add global mouse event monitors
        setupEventMonitoring()
        
        // 5. Register for window hide notification
        NotificationCenter.default.addObserver(self, selector: #selector(hideWindow), name: Notification.Name("HideMainWindow"), object: nil)
    }

    // MARK: - Setup Methods

    private func setupMainWindow() {
        let contentView = PopView()
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 300),
            styleMask: [.fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)

        let hostingView = NSHostingView(rootView: contentView
            .environmentObject(AppDelegate.shared))
        hostingView.autoresizingMask = [.width, .height]
        window?.contentView = hostingView
        window?.setContentSize(hostingView.fittingSize)
        configureWindowAppearance()

        window?.orderOut(nil) // Initially hide the window
    }

    private func configureWindowAppearance() {
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        window.acceptsMouseMovedEvents = true
    }

    private func setupStatusBar(eventMonitor: MouseEventMonitor) {
        statusBarManager = StatusBarManager(eventMonitor: eventMonitor)
        statusBarManager.addMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "", target: self)
        statusBarManager.addMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "", target: self)
    }
    
    private func setupEventMonitoring() {
        let doubleClick = DoubleClickCombination()
        doubleClick.onTrigger = {
            Task { // 启动一个异步任务
                do {
                    // 调用异步函数并处理结果
                    self.selectedText = try await self.manager.getSelectedText()
                    await self.showWindow()
                    print("Selected text: \(self.selectedText ?? "")")
                } catch {
                    await self.hideWindow_new()
//                    self.hideWindow()
                    // 处理 getSelectedText_new() 抛出的错误
                    print("Failed to get selected text: \(error)")
                }
            }
        }
        
        let dragAndDrop = DragAndDropCombination(dragThreshold: 3)
        dragAndDrop.onTrigger = {
            Task { // 启动一个异步任务
                do {
                    // 调用异步函数并处理结果
                    self.selectedText = try await self.manager.getSelectedText()
                    await self.showWindow()
                    print("Selected text: \(self.selectedText ?? "")")
                } catch {
                    // 处理 getSelectedText_new() 抛出的错误
                    await self.hideWindow_new()
//                    self.hideWindow()
                    print("Failed to get selected text: \(error)")
                }
            }
        }
        
        let scrollCombination = ScrollCombination()
        scrollCombination.onTrigger = {
            self.hideWindowWithAnimation()
        }
        
        eventMonitor.addCombination(doubleClick)
        eventMonitor.addCombination(dragAndDrop)
        eventMonitor.addCombination(scrollCombination)
        eventMonitor.addCombination(CustomMouseEventHandler { event in
            switch event {
            case .mouseDown(_):
                Task { @MainActor in
                    self.hideWindow_new()
                }
            case .mouseDragged(_):
                Task { @MainActor in
                    self.hideWindow_new()
                }
            case .mouseUp(_):
                break
            case .scrollWheel:
                Task { @MainActor in
                    self.hideWindow_new()
                }
            case .mouseMoved(_):
                Task { @MainActor in
                    self.handleMouseMoved()
                }
            }
            return false
        })
    }

    private func handleMouseMoved() {
        guard let panel = window, panel.isVisible else { return }
        let mouseLocation = NSEvent.mouseLocation
        if panel.frame.contains(mouseLocation) {
            cancelHideTimer()
        } else {
            startHideTimer()
        }
    }
    
    @MainActor private func handleScrollWheelEvent(_ event: NSEvent) {
        guard let panel = window, panel.isVisible else { return }
        
        // Check for a significant upward scroll (simulating a swipe up gesture)
        if event.deltaY > 10 {
             let currentMouseLocation = NSEvent.mouseLocation
             if let lastLocation = self.lastMouseLocation {
                 if abs(currentMouseLocation.x - lastLocation.x) < 10 {
                    hideWindow_new()
                 }
             }
             self.lastMouseLocation = currentMouseLocation
        }
        
        // If it's not a significant up scroll, reset the last mouse location
        else {
            self.lastMouseLocation = nil
        }
    }

    private func isForbiddenApp(_ bundleIdentifier: String) -> Bool {
        guard let forbiddenAppIDs = forbiddenAppIDs else { return false }
        return forbiddenAppIDs.contains(bundleIdentifier)
    }

    private func startHideTimer() {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.hideWindowIfNeeded()
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func hideWindowIfNeeded() {
        guard let panel = window else { return }
        let mouseLocation = NSEvent.mouseLocation
        if !panel.frame.contains(mouseLocation) {
            hideWindowWithAnimation()
        }
    }

    private func hideWindowWithAnimation() {
        guard let panel = window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0.0
        }) {
            panel.alphaValue = 1.0
            panel.orderOut(nil)
        }
    }
    
    private func isSelectedTextValid() -> Bool {
        guard let currentText = selectedText, !currentText.isEmpty else {
            return false
        }
        if currentText != lastSelectedText {
            return true
        }
        return false
    }
    
    @MainActor
    private func showWindow() {
        if !isSelectedTextValid() {
            return
        }

        if ExtensionManager.isExtensionString(selectedText!) {
            isExtension = true
            extensionObj = try? ExtensionManager.fromYAML(selectedText!)
        } else {
            isExtension = false
        }

        let mouseLocation = eventMonitor.lastMouseUpLocation

        Task { @MainActor in
            // 等待 SwiftUI 更新视图
            try? await Task.sleep(nanoseconds: 1_000_000) // 1 毫秒的延迟，可以根据情况调整

            if let contentView = window.contentView {
                contentView.layoutSubtreeIfNeeded()
                let contentSize = contentView.fittingSize
                window.setContentSize(contentSize)
                print("contentsize: \(contentSize)")

                // 在设置 contentSize 之后获取 window.frame.size
                let windowSize = window.frame.size
                let newOrigin = NSPoint(x: mouseLocation!.x - windowSize.width / 2, y: mouseLocation!.y + 10)
                window.setFrameOrigin(newOrigin)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }


    @MainActor
    public func hideWindow_new() {
        window.orderOut(nil)
    }
    
    // MARK: - Helper Methods

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print(TextSelectionError.accessibilityPermissionDenied.description())
        }
    }

    private func loadForbiddenApps() {
        if let savedData = UserDefaults.standard.array(forKey: "forbiddenApps") as? [[String: String]] {
            forbiddenAppIDs = Set(savedData.compactMap { $0["bundleIdentifier"] })
        }
    }

    
    // MARK: - Menu Actions
    @objc func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            createSettingsWindow()
        }
    }

    private func createSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)

        window.title = "Settings"
        window.contentView = NSHostingView(rootView: SettingView()
            .environmentObject(ProviderManager.shared)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ExtensionManager.shared)
            .environmentObject(LanguageManager.shared))

        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: nil
        ) { [weak self] _ in
            self?.settingsWindow = nil
        }
    }

    
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    
    // MARK: - NSWindow Notifications
    @objc private func hideWindow() {
        window?.orderOut(nil)
    }
}
