//
//  TransPanelManager.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Cocoa

class TransPanelManager: NSObject, ObservableObject, NSWindowDelegate {
    @Published var panel: TransPanel?
    private var query: String = ""
    private var globalMonitor: Any? // 改为可选类型
    private var localMonitor: Any?  // 改为可选类型
    
    
    func showPanel(query: String) {
        self.query = query
        let mouseLocation = NSEvent.mouseLocation
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 600

        // 如果 panel 已经存在，则移动到新的鼠标位置
        if let existingPanel = panel {
            let newPanelPosition = calculatePanelPosition(mouseLocation: mouseLocation, panelWidth: panelWidth, panelHeight: panelHeight)
            existingPanel.setFrameOrigin(newPanelPosition)
            if let existingViewController = existingPanel.contentViewController as? TransPanelViewController {
                // 现在可以使用 existingViewController
                existingViewController.setQuery(query: query)
            }
            return
        }

        // 如果没有面板存在，创建一个新的面板
        guard let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) else {
            let panelX = (NSScreen.main?.frame.width ?? 800 - panelWidth) / 2
            let panelY = (NSScreen.main?.frame.height ?? 600 - panelHeight) / 2
            createAndShowPanel(at: NSPoint(x: panelX, y: panelY), width: panelWidth, height: panelHeight)
            return
        }

        var panelX = mouseLocation.x
        var panelY = mouseLocation.y - 10

        if panelX + panelWidth > screen.frame.maxX {
            panelX = screen.frame.maxX - panelWidth - 10
        }
        if panelY < screen.frame.minY {
            panelY = mouseLocation.y + 10
        }

        createAndShowPanel(at: NSPoint(x: panelX, y: panelY), width: panelWidth, height: panelHeight)
    }

    private func calculatePanelPosition(mouseLocation: NSPoint, panelWidth: CGFloat, panelHeight: CGFloat) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) else {
            return NSPoint(x: (NSScreen.main?.frame.width ?? 800 - panelWidth) / 2,
                           y: (NSScreen.main?.frame.height ?? 600 - panelHeight) / 2)
        }

        var panelX = mouseLocation.x
        var panelY = mouseLocation.y - panelHeight - 10

        if panelX + panelWidth > screen.frame.maxX {
            panelX = screen.frame.maxX - panelWidth - 10
        }
        if panelY < screen.frame.minY {
            panelY = mouseLocation.y + 10
        }

        return NSPoint(x: panelX, y: panelY)
    }
    
    private func createAndShowPanel(at origin: NSPoint, width: CGFloat, height: CGFloat) {
        let panelRect = NSRect(x: origin.x, y: origin.y, width: width, height: height)

        let newPanel = TransPanel(contentRect: panelRect,
                                    styleMask: [.nonactivatingPanel, .fullSizeContentView],
                                    backing: .buffered,
                                    defer: false)

        newPanel.alphaValue = 0.0
        newPanel.contentViewController = TransPanelViewController(query: self.query)
        newPanel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            newPanel.animator().alphaValue = 1.0
        }, completionHandler: nil)

        newPanel.delegate = self
        panel = newPanel

        // 添加监听器
        addGlobalAndLocalMonitors()
    }

    private func addGlobalAndLocalMonitors() {
        // 全局监听器
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return }
            self.handleGlobalClick(event: event)
        }

        // 局部监听器
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return event }
            self.handleLocalClick(event: event)
            return event
        }
    }

    private func handleGlobalClick(event: NSEvent) {
        guard let panel = panel else { return }
        // 如果面板是置顶状态，不关闭
        if panel.isAlwaysOnTop {
            return
        }

        let clickLocation = NSEvent.mouseLocation // 全局屏幕坐标
        if !panel.frame.contains(clickLocation) {
            dismissPanel()
        }
    }

    private func handleLocalClick(event: NSEvent) {
        guard let panel = panel else { return }

        // 如果面板是置顶状态，不关闭
        if panel.isAlwaysOnTop {
            return
        }
        
        // 判断事件是否有窗口，转换为屏幕坐标
        if let eventWindow = event.window {
            let localClickLocation = event.locationInWindow
            let screenLocation = eventWindow.convertToScreen(NSRect(origin: localClickLocation, size: .zero)).origin
            if !panel.frame.contains(screenLocation) {
                dismissPanel()
            }
        } else {
            // 如果事件没有窗口，直接关闭面板
            dismissPanel()
        }
    }

    func dismissPanel() {
        guard let panel = panel else { return }
        self.panel = nil

        // 动画关闭
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.close()
            self.removeMonitors()
        })
    }

    private func removeMonitors() {
        if let globalMonitor = self.globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = self.localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeMonitors()
    }

    deinit {
        removeMonitors()
    }
}
