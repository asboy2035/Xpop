//
//  StatusBarManager.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import AppKit
import SwiftUI

class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var enableSwitch: NSSwitch?
    private var enableMenuItem: NSMenuItem?
    private var menu: NSMenu?

    private var infoPopover: NSPopover?
    private var timer: Timer?

    private var eventMonitor: InputEventMonitor?

    private let logger = Logger.shared

    private let userDefaultsKey = "isXpopEnabled"

    private var isEnabled: Bool {
        didSet {
            print("isEnabled: \(isEnabled)")
            UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
            if isEnabled {
                eventMonitor!.startGlobalMonitoring()
            } else {
                eventMonitor?.stopMonitoring()
            }
            updateButtonAppearance()
        }
    }

    init(eventMonitor: InputEventMonitor) {
        isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        self.eventMonitor = eventMonitor

        if isEnabled {
            eventMonitor.startGlobalMonitoring()
        }
        super.init()
        setupStatusBar()
        // 监听 effectiveAppearance 的变化
        NSApp.addObserver(self, forKeyPath: "effectiveAppearance", options: .new, context: nil)
    }

    deinit {
        // 移除监听
        NSApp.removeObserver(self, forKeyPath: "effectiveAppearance")
    }    

    override func observeValue(
        forKeyPath keyPath: String?,
        of _: Any?,
        change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        if keyPath == "effectiveAppearance" {
            // 当 effectiveAppearance 变化时，更新菜单外观
            updateMenuAppearance()
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let appIcon = NSImage(named: "AppIcon") {
                appIcon.size = NSSize(width: 24, height: 24)

                // 创建一个新的 NSImage，用于绘制修改后的图像
                let tintedImage = NSImage(size: appIcon.size)
                tintedImage.lockFocus() // 开始绘制

                // 将原始图像绘制到新图像中
                appIcon.draw(at: .zero, from: NSRect(origin: .zero, size: appIcon.size), operation: .sourceOver, fraction: 1.0)

                // 设置绘图上下文的颜色
                NSColor.white.set()
                NSRect(origin: .zero, size: appIcon.size).fill(using: .sourceAtop) // 使用混合模式覆盖颜色

                tintedImage.unlockFocus() // 完成绘制

                // 设置按钮的图像
                button.image = tintedImage
                button.alphaValue = isEnabled ? 1.0 : 0.4
            }

            // 设置按钮的目标动作
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))

            // 移除默认的菜单行为
            statusItem?.menu = nil
        }

        // 创建菜单但不立即绑定到状态栏
        buildMenu()
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)

        // 显示菜单
        if let menu = menu {
            let point = NSPoint(x: 0, y: NSStatusBar.system.thickness)
            menu.popUp(positioning: nil, at: point, in: sender)
        }
    }

    private func updateButtonAppearance() {
        if let button = statusItem?.button {
            button.alphaValue = isEnabled ? 1.0 : 0.4
        }
    }

    private func buildMenu() {
        menu = NSMenu()
        updateMenuAppearance()
        enableMenuItem = createEnableMenuItem()
        menu?.addItem(enableMenuItem!)
        menu?.addItem(NSMenuItem.separator())
    }

    @objc private func updateMenuAppearance() {
        if let menu = menu {
            menu.appearance = NSApp.effectiveAppearance
        }
    }

    private func createEnableMenuItem() -> NSMenuItem {
        let enableView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))

        let enableLabel = NSTextField(labelWithString: "Xpop")
        enableLabel.frame = NSRect(x: 12, y: 5, width: 80, height: 18)
        enableLabel.font = NSFont.boldSystemFont(ofSize: 14)
        enableView.addSubview(enableLabel)

        enableSwitch = NSSwitch()
        enableSwitch?.frame = NSRect(x: 140, y: 5, width: 60, height: 18)
        enableSwitch?.target = self
        enableSwitch!.isEnabled = true
        let isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        enableSwitch?.state = isEnabled ? .on : .off
        enableSwitch?.action = #selector(enableSwitchChanged(_:))
        enableView.addSubview(enableSwitch!)

        let menuItem = NSMenuItem()
        menuItem.view = enableView
        menuItem.isEnabled = true

        return menuItem
    }

    func addMenuItem(title: String, action: Selector, keyEquivalent: String, target: AnyObject? = nil) {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.target = target ?? self
        menu?.addItem(menuItem)
    }

    @objc private func enableSwitchChanged(_ sender: NSSwitch) {
        if sender.state == .on {
            isEnabled = true
            logger.log("Xpop is ON.", type: .debug)
        } else {
            isEnabled = false
            logger.log("Xpop is OFF.", type: .debug)
        }
    }

    func showSuccessMessage() {
        showMessage(imageName: "checkmark.circle.fill", color: .green, message: "插件安装成功")
    }

    func showFailureMessage() {
        showMessage(imageName: "xmark.circle.fill", color: .red, message: "插件安装失败")
    }

    private func showMessage(imageName: String, color: Color, message: String) {
        guard let statusItem = statusItem, let button = statusItem.button else { return }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 200, height: 60)
        popover.behavior = .transient

        let hostingController = NSHostingController(rootView: PopoverContentView(
            imageName: imageName,
            color: color,
            message: message
        ))
        popover.contentViewController = hostingController

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        infoPopover = popover

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            self.hidePopover()
        }
    }

    private func hidePopover() {
        infoPopover?.close()
        infoPopover = nil
        timer?.invalidate()
        timer = nil
    }
}
