//
//  StatusBarManager.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import AppKit

class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var enableSwitch: NSSwitch? // 保存开关的引用
    private var enableMenuItem: NSMenuItem? // 保存菜单项的引用
    private var menu: NSMenu?
    
    private var eventMonitor: MouseEventMonitor?
    
    private let logger = Logger.shared

    private let userDefaultsKey = "isXpopEnabled"
    private var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
            // 根据状态启动或停止鼠标事件监控
            if isEnabled {
                eventMonitor!.startGlobalMonitoring()
            } else {
                eventMonitor?.stopMonitoring()
            }
            
            // 更新按钮的透明度
            updateButtonAppearance()
        }
    }

    init(eventMonitor: MouseEventMonitor) {
        // 从 UserDefaults 中读取状态，如果不存在则默认为 true（启用）
        self.isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        self.eventMonitor = eventMonitor

        // 根据当前状态启动或停止监控
        if isEnabled {
            eventMonitor.startGlobalMonitoring()
        }
        super.init()
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let appIcon = NSImage(named: "AppIcon") {
                appIcon.size = NSSize(width: 24, height: 24)
                button.image = appIcon
            }
        }
        buildMenu()
    }
    
    private func updateButtonAppearance() {
        if let button = statusItem?.button {
            button.alphaValue = isEnabled ? 1.0 : 0.4 // 根据 isEnabled 设置透明度
        }
    }

    private func buildMenu() {
        menu = NSMenu()

        // 创建 enableMenuItem
        enableMenuItem = createEnableMenuItem()
        menu?.addItem(enableMenuItem!)
        menu?.addItem(NSMenuItem.separator())

        statusItem?.menu = menu
    }

    private func createEnableMenuItem() -> NSMenuItem {
        // 创建包含 NSSwitch 的自定义 View
        let enableView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))

        // 添加 Enable 标签
        let enableLabel = NSTextField(labelWithString: "Xpop")
        enableLabel.frame = NSRect(x: 12, y: 5, width: 80, height: 18)
        enableLabel.font = NSFont.boldSystemFont(ofSize: 14) // 设置字体加粗
        enableView.addSubview(enableLabel)
        // 添加 NSSwitch
        enableSwitch = NSSwitch()
        enableSwitch?.frame = NSRect(x: 140, y: 5, width: 60, height: 18)
        enableSwitch?.target = self // 设置目标
        enableSwitch!.isEnabled = true // 确保开关启用
        let isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey) // 从用户设置获取值
        enableSwitch?.state = isEnabled ? .on : .off
        enableSwitch?.action = #selector(enableSwitchChanged(_:))
        enableView.addSubview(enableSwitch!)
        
        // 创建 NSMenuItem 并设置 view
        let menuItem = NSMenuItem()
        menuItem.view = enableView
        menuItem.isEnabled = true // 确保菜单项启用

        return menuItem
    }

    // 公开方法：添加菜单项
    func addMenuItem(title: String, action: Selector, keyEquivalent: String, target: AnyObject? = nil) {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.target = target ?? self // 如果未指定 target，则默认使用 self
        menu?.addItem(menuItem)
    }

    @objc private func enableSwitchChanged(_ sender: NSSwitch) {
        if sender.state == .on {
            isEnabled = true
            logger.log("Xpop is ON.", type: .debug)
        } else {
            isEnabled = false
            logger.log("Xpop is OFF.", type: .debug)
            // 执行禁用应用程序的逻辑
        }
    }
}
