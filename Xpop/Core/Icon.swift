//
//  Icon.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI

struct CustomImage: View {
    let extName: String
    let iconString: String
    let size: CGFloat
    let cornerRadius: CGFloat = 8

    @Environment(\.colorScheme) private var colorScheme

    init(extName: String, iconString: String, size: CGFloat = 30) {
        self.extName = extName
        self.iconString = iconString
        self.size = size
    }

    private var parsedModifiers: [String: String] {
        let components = iconString.components(separatedBy: " ")
        var modifiers: [String: String] = [:]
        for component in components {
            if component.hasPrefix("symbol:") {
                modifiers["symbol"] = String(component.dropFirst("symbol:".count))
            } else if component.contains("=") {
                let parts = component.components(separatedBy: "=")
                modifiers[parts[0]] = parts[1]
            } else {
                modifiers[component] = "true"
            }
        }
        return modifiers
    }

    private var iconText: String {
        let components = iconString.components(separatedBy: " ")
        let textComponents = components.filter { !$0.hasPrefix("symbol:") && !$0.contains("=") }
        return String(textComponents.last?.prefix(8) ?? "")
    }

    private var isSFSymbol: Bool {
        parsedModifiers["symbol"] != nil
    }

    private var sfSymbolName: String {
        parsedModifiers["symbol"] ?? ""
    }

    private var isPNGImage: Bool {
        iconString.contains(".png")
    }

    private var pngImageName: String {
        let components = iconString.components(separatedBy: " ")
        return components.first { $0.contains(".png") } ?? ""
    }

    private var backgroundShape: some View {
        if parsedModifiers["circle"] == "true" {
            if parsedModifiers["filled"] == "true" {
                AnyView(Circle().fill(filledBackgroundColor))
            } else {
                AnyView(Circle().stroke(Color.primary, lineWidth: 2))
            }
        } else if parsedModifiers["square"] == "true" {
            if parsedModifiers["filled"] == "true" {
                AnyView(RoundedRectangle(cornerRadius: cornerRadius).fill(filledBackgroundColor))
            } else {
                AnyView(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.primary, lineWidth: 2))
            }
        } else {
            AnyView(RoundedRectangle(cornerRadius: cornerRadius).fill(Color.clear))
        }
    }

    private var filledBackgroundColor: Color {
        colorScheme == .light ? .white : .black
    }

    private var filledTextColor: Color {
        colorScheme == .light ? .black : .white
    }

    private var strikeLineColor: Color {
        colorScheme == .light ? (parsedModifiers["filled"] == "true" ? filledTextColor : Color.primary) : .white
    }

    private var strikeBorderColor: Color {
        colorScheme == .light ? .white : .black
    }

    private var iconContent: some View {
        if isPNGImage {
            return AnyView(
                Image(nsImage: loadImageFromFileSystem(imageName: pngImageName))
                    .renderingMode(.template) // 正确应用于 Image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size - 5, height: size - 5)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary) // 使用系统主色
            )
        } else if parsedModifiers["search"] == "true" {
            return AnyView(
                Image(systemName: "magnifyingglass")
                    .font(.system(size: size * 0.5, weight: .bold))
            )
        } else if isSFSymbol {
            return AnyView(
                Image(systemName: sfSymbolName)
                    .font(.system(size: size * 0.5, weight: .bold))
            )
        } else {
            return AnyView(
                Text(iconText)
                    .font(parsedModifiers["monospaced"] == "true" ?
                        .system(size: size * 0.5, weight: .bold, design: .monospaced) :
                        .system(size: size * 0.5, weight: .bold, design: .default))
            )
        }
    }

    private var strikeLine: some View {
        if parsedModifiers["strike"] == "true" {
            AnyView(
                ZStack {
                    DiagonalStrikeLine()
                        .stroke(strikeBorderColor, lineWidth: 4)
                    DiagonalStrikeLine()
                        .stroke(strikeLineColor, lineWidth: 2)
                }
                .frame(width: size * 0.8, height: size * 0.8)
            )
        } else {
            AnyView(EmptyView())
        }
    }

    private var scale: CGFloat {
        CGFloat((parsedModifiers["scale"] ?? "100").toDouble() ?? 100) / 100
    }

    private var rotation: Double {
        parsedModifiers["rotate"]?.toDouble() ?? 0
    }

    private var moveX: CGFloat {
        CGFloat(parsedModifiers["move-x"]?.toDouble() ?? 0)
    }

    private var moveY: CGFloat {
        CGFloat(parsedModifiers["move-y"]?.toDouble() ?? 0)
    }

    private var flipX: Bool {
        parsedModifiers["flip-x"] == "true"
    }

    private var flipY: Bool {
        parsedModifiers["flip-y"] == "true"
    }

    var body: some View {
        ZStack {
            backgroundShape
            iconContent
            strikeLine
        }
        .frame(width: size, height: parsedModifiers["preserve-aspect"] != nil ? nil : size)
        .aspectRatio(parsedModifiers["preserve-aspect"] != nil ? nil : 1, contentMode: .fit)
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .offset(x: moveX, y: moveY)
        .flipped(horizontal: flipX, vertical: flipY)
    }

    private func loadImageFromFileSystem(imageName: String) -> NSImage {
        // 获取应用程序名称 (假设为 "Xpop")
        guard let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String else {
            print("Failed to get application name from Bundle.")
            return NSImage(named: "default_image") ?? NSImage()
        }

        // 获取 Application Support 目录
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        else {
            print("Failed to get Application Support directory.")
            return NSImage(named: "default_image") ?? NSImage()
        }

        // 构建完整的插件目录路径
        let extensionsDir = appSupportURL.appendingPathComponent("\(appName)/Extensions")

        guard let pluginDirName = ExtensionManager.shared.getExtensionDir(name: extName) else {
            print("Failed to get plugin directory name for: \(extName)")
            return NSImage(named: "default_image") ?? NSImage()
        }

        let pluginDir = extensionsDir.appendingPathComponent(pluginDirName)
        let imageURL = pluginDir.appendingPathComponent(imageName)

        print("Loading image from path: \(imageURL.path)")
        if let image = NSImage(contentsOf: imageURL) {
            return image
        } else {
            print("Failed to load image from path: \(imageURL.path)")
        }

        // 如果加载失败，返回一个默认图片
        return NSImage(named: "default_image") ?? NSImage()
    }
}

extension String {
    func toDouble() -> Double? {
        Double(self)
    }
}

struct DiagonalStrikeLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

extension View {
    func flipped(horizontal: Bool, vertical: Bool) -> some View {
        scaleEffect(x: horizontal ? -1 : 1, y: vertical ? -1 : 1, anchor: .center)
    }
}
