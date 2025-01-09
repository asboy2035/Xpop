//
//  ManageForbiddenApp.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI
import AppKit

struct ManageForbiddenAppView: View {
    @State private var forbiddenApps: [AppInfo] = []
    @State private var showSelection = false
    @State private var selectedApps: Set<String> = []

    var body: some View {
        VStack() {
            Text("Manage Forbidden Apps")
                .font(.title)
                .bold()
                .padding()
            
            Text("Xpop will not effect in the following apps.")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 0){
                ZStack{
                    Text("Forbidden Apps")
                        .padding(.top, 10)
                        .padding(.leading, 18)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1)) // 背景方便观察效果
                        .font(.system(size: 16)) // 设置字体大小为 18
                        .foregroundColor(Color.gray)
                    if showSelection {
                        Button(action:{
                            withAnimation{
                                deleteApps()
                                selectedApps.removeAll()
                                showSelection = false
                            }
                        }) {
                            Text("Delete")
                                .bold()
                        }
                        .buttonStyle(DeleteButtonStyle())
                        .background(Color.gray.opacity(0.5)) // 背景方便观察效果
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2) // 添加阴影
                    }
                }
                
                List() {
                    ForEach(forbiddenApps, id: \.id) { app in
                        ForbiddenAppRow(appInfo: app, showSelection: $showSelection, selectedApps: $selectedApps)
                    }
                }
                .scrollContentBackground(.hidden) // 隐藏背景
            }
            .onAppear {
                loadSavedApps()
                removeDeletedApps()
            }
            .background(Color.gray.opacity(0.1)) // Slightly darker
            .cornerRadius(10)
            .padding([.leading, .trailing], 30) // 设置左右内边距为 30

            HStack {
                // "+" Button
                Button(
                    action: openApplicationsFolder
                ) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2)) // Adjusted background for macOS
                        .cornerRadius(5)
                }
                .buttonStyle(BorderlessButtonStyle())

                // "-" Button
                Button(action: {
                    withAnimation{
                        showSelection.toggle()
                    }
                    if !showSelection {
                        selectedApps.removeAll() // Reset selections when canceling
                    }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2)) // Adjusted background for macOS
                        .cornerRadius(5)
                }
                .buttonStyle(BorderlessButtonStyle())
                
            }
            .padding()
        }
    }
    
    private func openApplicationsFolder() {
        let panel = NSOpenPanel()
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications") // 设置初始目录为 Applications 文件夹

        if panel.runModal() == .OK {
            let selectedURLs = panel.urls

            DispatchQueue.global(qos: .userInitiated).async {
                var newApps: [AppInfo] = []
                for url in selectedURLs {
                    guard let bundle = Bundle(url: url),
                          let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
                          let bundleIdentifier = bundle.bundleIdentifier else { continue }

                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    let iconPath = saveIconToFileSystem(icon: icon, appName: appName)

                    let app = AppInfo(
                        id: bundleIdentifier,
                        name: appName,
                        bundleIdentifier: bundleIdentifier,
                        path: url.path,
                        iconPath: iconPath
                    )

                    if !forbiddenApps.contains(where: { $0.id == app.id }) {
                        newApps.append(app)
                    }
                }

                DispatchQueue.main.async {
                    forbiddenApps.append(contentsOf: newApps)
                    saveAppsToUserDefaults()
                }
            }
        }
    }
    
    private func deleteApps() {
        forbiddenApps.removeAll { app in
            selectedApps.contains(app.id)
        }
        saveAppsToUserDefaults() // 保存更改
    }

    private func saveAppsToUserDefaults() {
        let appData = forbiddenApps.map {
            [
                "name": $0.name,
                "bundleIdentifier": $0.bundleIdentifier,
                "path": $0.path,
                "iconPath": $0.iconPath ?? "" // 保存图标路径
            ]
        }
        UserDefaults.standard.set(appData, forKey: "forbiddenApps")
    }

    private func loadSavedApps() {
//        UserDefaults.standard.removeObject(forKey: "selectedApps") //
        if let savedData = UserDefaults.standard.array(forKey: "forbiddenApps") as? [[String: String]] {
            var loadedApps: [AppInfo] = []
            for appInfo in savedData {
                if let name = appInfo["name"],
                   let bundleIdentifier = appInfo["bundleIdentifier"],
                   let path = appInfo["path"],
                   let iconPath = appInfo["iconPath"],
                   FileManager.default.fileExists(atPath: path) {

                    let app = AppInfo(
                        id: bundleIdentifier,
                        name: name,
                        bundleIdentifier: bundleIdentifier,
                        path: path,
                        iconPath: iconPath.isEmpty ? nil : iconPath
                    )
                    loadedApps.append(app)
                }
            }
            forbiddenApps = loadedApps
        }
    }

    private func removeDeletedApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            var validApps: [AppInfo] = []
            for app in forbiddenApps {
                if FileManager.default.fileExists(atPath: app.path) {
                    validApps.append(app)
                }
            }
            DispatchQueue.main.async {
                forbiddenApps = validApps
                saveAppsToUserDefaults()
            }
        }
    }

    private func saveIconToFileSystem(icon: NSImage, appName: String) -> String? {
        guard let iconData = icon.tiffRepresentation else { return nil }
        let directory = FileManager.default.temporaryDirectory
        let fileURL = directory.appendingPathComponent("\(appName).tiff")
        do {
            try iconData.write(to: fileURL)
            return fileURL.path
        } catch {
            return nil
        }
    }
}

struct ForbiddenAppRow: View {
    let appInfo: AppInfo
    @Binding var showSelection: Bool
    @Binding var selectedApps: Set<String>

    var body: some View {
        HStack {
            if showSelection {
                    Button(action: {
                        if selectedApps.contains(appInfo.id) {
                            selectedApps.remove(appInfo.id)
                        } else {
                            selectedApps.insert(appInfo.id)
                        }
                    }) {
                        Image(systemName: selectedApps.contains(appInfo.id) ? "checkmark.square.fill" : "square.fill")
                            .symbolRenderingMode(.palette) // 启用调色板渲染模式
                            .foregroundStyle(Color.white, Color.gray) // 外轮廓为灰色，填充为白色
                    }
                    .buttonStyle(.plain)
                    .background(.clear)
                    
            }
            if let icon = appInfo.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading) {
                Text(appInfo.name)
                    .font(.headline)
                Text(appInfo.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
        .background(.clear)
    }
}


struct AppInfo: Identifiable {
    let id: String // 唯一标识符，使用 bundleIdentifier
    let name: String
    let bundleIdentifier: String
    let path: String // 保存应用路径
    let iconPath: String? // 图标路径

    var icon: NSImage? { // 动态加载图标
        guard let iconPath = iconPath else { return nil }
        return NSImage(contentsOfFile: iconPath)
    }
}

struct ContentView: View {
    var body: some View {
        ManageForbiddenAppView()
    }
}


#Preview {
    ContentView()
}
