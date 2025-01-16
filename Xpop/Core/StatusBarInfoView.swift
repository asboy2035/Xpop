//
//  StatusBarInfoView.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/15.
//

import AppKit
import SwiftUI

struct PopoverContentView: View {
    var imageName: String
    var color: Color // 使用 SwiftUI 的 Color
    var message: String

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            HStack {
                Image(systemName: imageName)
                    .foregroundColor(color) // 直接使用 Color
                    .font(.system(size: 16))
                Text(message)
                    .font(.system(size: 14))
            }
            .padding()
        }
        .frame(width: 200, height: 60)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
