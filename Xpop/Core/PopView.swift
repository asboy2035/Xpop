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
            ZStack {
                Text("  Install Extension \(extensionName)")
                    .foregroundColor(isHovered ? Color.white : Color.primary) // 图标颜色随悬停状态变化
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 180, maxWidth: 240, maxHeight: .infinity) // 设置 frame，并允许垂直方向扩展
        .background(
            RoundedRectangle(cornerRadius: 8)
                .background(
                    isHovered ? Color.accent.opacity(0.8) : Color.clear
                )
        )
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
            if ext.buintinType == "_buildin" {
                BuiltInAction.actions[ext.name!]?()
            } else {
                ext.run(selectedText: appDelegate.selectedText)
            }
            appDelegate.hideWindow_new() // 点击按钮后隐藏窗口
        }) {
            HStack(spacing: 2) {
                if let icon = ext.icon, !icon.isEmpty,
                   let name = ext.name, !name.isEmpty {
                    CustomImage(extName: "Unknown", iconString: icon, size: 28)
                    Text(name)
                        .padding(.trailing, 6)
                } else if let icon = ext.icon, !icon.isEmpty {
                    // Show icon only, fallback name as "Unknown" or similar if needed
                    CustomImage(extName: "Unknown", iconString: icon, size: 28)
                } else if let name = ext.name, !name.isEmpty {
                    Text(name)
                        .lineLimit(1)
                        .frame(maxHeight: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                } else {
                    Image(systemName: "questionmark.circle")
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 填充整个按钮区域
            .contentShape(Rectangle()) // 确保整个区域都可点击
            .foregroundColor(isHovered ? Color.white : Color.primary)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 30)
        .frame(minWidth: 60, maxWidth: 200, maxHeight: .infinity) // 设置灵活的宽度和高度
        .fixedSize()
        .layoutPriority(1) // 提高按钮的布局优先级
        .background(isHovered ? Color.accent.opacity(0.8) : Color.clear)
        .mask(
            RoundedRectangle(cornerRadius: 10)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct BlurEffectWithOpacityView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true // 必须启用 layer

        let blurView = NSVisualEffectView()
        blurView.state = .active
        blurView.material = .hudWindow // 默认材质，可根据需要更改
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

        return containerView
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        guard let blurView = nsView.subviews.first as? NSVisualEffectView else { return }
        updateAppearance(for: blurView)

    }

    private func updateAppearance(for view: NSVisualEffectView) {
        if isDarkMode() {
            view.material = .windowBackground // 深色模式使用 windowBackground
        } else {
            view.material = .contentBackground // 浅色模式使用 contentBackground
        }
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
        HStack(spacing: 0) {
            // 使用 InstallButton
            // Use a Group and set an id based on appDelegate.isExtension
            Group {
                if appDelegate.isExtension {
                    let name = appDelegate.extensionObj!.name!
                    InstallButton(action: {
                        Task {
                            do {
                                _ = try extensionManager.install(ext: appDelegate.extensionObj!)
                                appDelegate.statusBarManager.showSuccessMessage()
                            } catch {
                                appDelegate.statusBarManager.showFailureMessage()
                            }
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
        .padding(6)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16)) // 添加圆角背景
        )
    }
}

#Preview {
    PopView()
}
