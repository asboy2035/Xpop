//
//  PopView.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import AppKit
import Combine
import SwiftUI

struct InstallButton: View {
    var action: () -> Void
    var extensionName: String
    
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("  Install Extension \(extensionName)")
                .foregroundColor(isHovered ? Color.white : Color.primary) // 图标颜色随悬停状态变化
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 180, maxWidth: 240, maxHeight: .infinity) // 设置 frame，并允许垂直方向扩展
        .background(isHovered ? Color.blue.opacity(0.8) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ExtensionButton: View {
    let ext: Extension
    @State private var isHovered = false
    @ObservedObject var appDelegate = AppDelegate.shared

    var body: some View {
        Button(action: {
            if ext._buildin_type == "_buildin" {
                BuiltInAction.actions[ext.name!]?()
            } else {
                ext.run(selectedText: appDelegate.selectedText)
            }
            appDelegate.hideWindow_new() // 点击按钮后隐藏窗口
        }) {
            // 如果有 icon，显示 CustomImage；否则显示 Text
            if let icon = ext.icon, !icon.isEmpty {
                CustomImage(iconString: icon, size: 30)
                    .foregroundColor(isHovered ? Color.white : Color.primary)
                
            } else if let name = ext.name, !name.isEmpty {
                Text(name)
                    .foregroundColor(isHovered ? Color.white : Color.primary)
                    .lineLimit(1) // 限制为单行
                    .fixedSize(horizontal: true, vertical: false) // 确保文本完整显示
            } else {
                // 如果 icon 和 name 都为空，显示一个占位符（可选）
                Image(systemName: "questionmark.circle") // 使用系统图标作为占位符
                    .foregroundColor(isHovered ? Color.white : Color.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 40, maxWidth: .infinity, maxHeight: .infinity) // 设置灵活的宽度和高度
        .background(isHovered ? Color.blue.opacity(0.8) : Color.clear)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct BlurEffectWithOpacityView: NSViewRepresentable {
    var opacity: Double

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true // 必须启用 layer

        let blurView = NSVisualEffectView()
        blurView.state = .active
        blurView.material = .contentBackground // 默认材质，可根据需要更改
        blurView.blendingMode = .behindWindow // 默认混合模式，可根据需要更改
        blurView.translatesAutoresizingMaskIntoConstraints = false // 启用自动布局

        containerView.addSubview(blurView)

        // 使用约束使 blurView 填充 containerView
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        updateAppearance(for: blurView)
        updateOpacity(for: containerView)

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let blurView = nsView.subviews.first as? NSVisualEffectView else { return }
        updateAppearance(for: blurView)
        updateOpacity(for: nsView)
    }

    private func updateAppearance(for view: NSVisualEffectView) {
        if isDarkMode() {
            view.material = .windowBackground // 深色模式使用 windowBackground
        } else {
            view.material = .contentBackground // 浅色模式使用 contentBackground
        }
    }

    private func updateOpacity(for view: NSView) {
        view.alphaValue = opacity
    }

    private func isDarkMode() -> Bool {
        guard let appearance = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) else {
            return false
        }
        return appearance == .darkAqua
    }
}

struct PopView: View {
    @ObservedObject var appDelegate = AppDelegate.shared
    @ObservedObject var extensionManager = ExtensionManager.shared
    @ObservedObject var menuActionStateManager = MenuActionStateManager.shared

    var body: some View {
        ZStack {
            BlurEffectWithOpacityView(opacity: 0.7)
                .edgesIgnoringSafeArea(.all)
                .clipShape(RoundedRectangle(cornerRadius: 6)) // 添加圆角背景

            HStack(spacing: 0) {
                // 使用 InstallButton
                // Use a Group and set an id based on appDelegate.isExtension
                Group {
                    if appDelegate.isExtension {
                        let name = appDelegate.extensionObj!.name!
                        InstallButton(action: {
                            Task {
                                try? extensionManager.install(ext: appDelegate.extensionObj!)
                                appDelegate.hideWindow_new()
                            }
                        }, extensionName: name)
                    }
                }
                .id(appDelegate.isExtension) // Add an id here
                ForEach(extensionManager.extensionList) { extItem in
                    if extItem.isEnabled {
                        if extItem.name == "_XPOP_BUILDIN_CUT" {
                            if menuActionStateManager.canCut {
                                ExtensionButton(ext: extensionManager.extensions[extItem.name]!)
                            }
                        } else if extItem.name == "_XPOP_BUILDIN_PASTE" {
                            if menuActionStateManager.canPaste {
                                ExtensionButton(ext: extensionManager.extensions[extItem.name]!)
                            }
                        } else {
                            ExtensionButton(ext: extensionManager.extensions[extItem.name]!)
                        }
                    }
                }
            }
        }
        .frame(height: 28) // 确保整个 ToolbarView 的高度
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

//#Preview {
//    PopView()
//}
