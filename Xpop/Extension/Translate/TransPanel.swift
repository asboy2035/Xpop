//
//  TransPanel.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import Cocoa

class TransPanel: NSPanel {
    // 是否置顶的状态
    var isAlwaysOnTop: Bool = false {
        didSet {
            level = isAlwaysOnTop ? .floating : .normal
        }
    }

    override init(contentRect: NSRect,
                  styleMask: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType,
                  defer flag: Bool) {
        super.init(contentRect: contentRect,
                   styleMask: styleMask,
                   backing: backingStoreType,
                   defer: flag)
        isFloatingPanel = true
        level = .floating
        hasShadow = true
        isOpaque = false
        backgroundColor = NSColor.clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .transient]
    }

    override var canBecomeKey: Bool {
        true
    }
}
