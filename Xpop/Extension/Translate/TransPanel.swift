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
            self.level = isAlwaysOnTop ? .floating : .normal
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
        self.isFloatingPanel = true
        self.level = .floating
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient]
    }

    override var canBecomeKey: Bool {
        return true
    }
}
