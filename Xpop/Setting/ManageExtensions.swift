//
//  ManageExtensions.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI

// MARK: - ExtensionRow 视图
struct ExtensionRow: View {
    let ext: Extension
    let isEditing: Bool
    let isSelected: Bool
    let onToggleSelection: (Bool) -> Void
    let onDelete: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if isEditing {
                    Button(action: {
                        onDelete()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity)
                } else {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { isEnabled in
                            onToggleSelection(isEnabled)
                        }
                    ))
                    .toggleStyle(MacCheckboxToggleStyle())
                    .frame(width: 24, height: 24)
                    .transition(.opacity)
                }
                if let icon = ext.icon, !icon.isEmpty {
                    CustomImage(extName: ext.name!, iconString: ext.icon!)
                }
//                    .foregroundColor(Color(NSColor.labelColor))
//                    .transition(.opacity)

                Text(ext.localizedName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)

                Button(action: {
                    onSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)

                Image(systemName: "line.horizontal.3")
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                    .transition(.opacity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .padding(.leading, 16)
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

// MARK: - 自定义 macOS 风格的勾选框样式
struct MacCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Button {
                configuration.isOn.toggle()
            } label: {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .blue : .gray)
                    .font(.system(size: 16, weight: .regular, design: .default))
            }
            .buttonStyle(PlainButtonStyle())
            configuration.label
        }
    }
}



// MARK: - ExtensionManagerView 主视图
struct ExtensionManagerView: View {
    @StateObject var extManager = ExtensionManager.shared
    @State private var isEditing = false
    @State private var selectedPluginForSettings: Extension? = nil
    @State private var showOtherView = false
    
    @Environment(\.locale) var locale

    var body: some View {
        
        VStack {
            Text("Extension Management")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 16)
            VStack(spacing: 0) {
                ZStack {
                    Text("Installed Extensions")
                        .padding(.top, 10)
                        .padding(.leading, 18)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1)) // 背景方便观察效果
                        .font(.system(size: 16)) // 设置字体大小为 18
                        .foregroundColor(Color.gray)
                }
                VStack {
                    List {
                        ForEach(extManager.extensionList) { ext in
                            ExtensionRow(
                                ext: extManager.getExtensionByName(name: ext.name),
                                isEditing: isEditing,
                                isSelected: ext.isEnabled,
                                onToggleSelection: { isEnabled in
                                    withAnimation {
                                        extManager.updateExtensionState(extName: ext.name, isEnabled: isEnabled)
                                    }
                                },
                                onDelete: {
                                    extManager.deleteExtension(extensionName: ext.name)
                                },
                                onSettings: {
                                    selectedPluginForSettings = extManager.getExtensionByName(name: ext.name)
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                        .onMove(perform: extManager.moveExtensions)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .cornerRadius(6)
            .padding([.leading, .trailing], 30) // 设置左右内边距为 30
        
            HStack {
                Button(action: {
                    withAnimation {
                        isEditing.toggle()
                    }
                }) {
                        Text(isEditing ? "Cancel" : "Edit")
                }
                .transition(.scale(scale: isEditing ? 1.2 : 1))
                .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3), value: isEditing)
            }
            .padding(.leading, 30)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - PluginSettingsView 设置视图
struct PluginSettingsView: View {
    let ext: Extension
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Settings for \(ext.localizedName)")
                .font(.title)
                .padding()

//            Text("Description: \(ext.description!)")
//                .padding()

            Spacer()

            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 200)
        .padding()
    }
}
