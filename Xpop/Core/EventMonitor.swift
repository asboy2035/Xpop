//
//  EventMonitor.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import SwiftUI
import Cocoa

// 定义鼠标事件类型
enum MouseEvent {
    case mouseDown(NSEvent)
    case mouseDragged(NSEvent)
    case mouseUp(NSEvent)
    case mouseMoved(NSEvent)
    case scrollWheel(NSEvent)
}

// 定义一个抽象的鼠标事件组合    
protocol MouseEventCombination {
    var identifier: String { get }
    func handleEvent(_ event: MouseEvent) -> Bool
    var onTrigger: (() -> Void)? { get set }
}

// 鼠标事件监控类
class MouseEventMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var eventCombinations: [MouseEventCombination] = []
    
    // 最近的鼠标按下和弹起位置（只允许外部读取）
    private(set) var lastMouseDownLocation: NSPoint? // 只读
    private(set) var lastMouseUpLocation: NSPoint? // 只读

    init() {}

    // 注册本地事件监控
    func startLocalMonitoring() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged,.mouseMoved, .scrollWheel]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    // 注册全局事件监控
    func startGlobalMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .mouseMoved, .scrollWheel]) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    // 停止事件监控
    public func stopMonitoring() {
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor = globalMonitor {

            NSEvent.removeMonitor(globalMonitor)
        }
        self.localMonitor = nil
        self.globalMonitor = nil
    }

    // 添加鼠标事件组合
    func addCombination(_ combination: MouseEventCombination) {
        eventCombinations.append(combination)
    }

    // 处理事件并分发给组合
    private func handleEvent(_ event: NSEvent) {
        let mouseEvent: MouseEvent
        switch event.type {
        case .leftMouseDown:
            mouseEvent = .mouseDown(event)
            lastMouseDownLocation = event.locationInWindow // 记录鼠标按下位置
        case .leftMouseDragged:
            mouseEvent = .mouseDragged(event)
        case .leftMouseUp:
            mouseEvent = .mouseUp(event)
            lastMouseUpLocation = event.locationInWindow // 记录鼠标弹起位置
        case .scrollWheel:
            mouseEvent = .scrollWheel(event) // 处理滚轮事件
        case .mouseMoved:
            mouseEvent = .mouseMoved(event)
        default:
            return
        }

        for combination in eventCombinations {
            if combination.handleEvent(mouseEvent) {
//                combination.onTrigger?()
                // 添加延迟以处理鼠标抖动
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    combination.onTrigger?()
                }
            }
        }
    }
}

// 鼠标双击事件的组合
class DoubleClickCombination: MouseEventCombination {
    let identifier: String
    var onTrigger: (() -> Void)?

    init(identifier: String = "DoubleClick") {
        self.identifier = identifier
    }

    func handleEvent(_ event: MouseEvent) -> Bool {
        switch event {
        case .mouseDown(let e):
            // 检查是否为双击事件
            if e.clickCount == 2 {
                return true
            }
        default:
            break
        }
        return false
    }
}

// 滚轮事件的组合
class ScrollCombination: MouseEventCombination {
    let identifier: String
    var onTrigger: (() -> Void)?
    
    init(identifier: String = "Scroll") {
        self.identifier = identifier
    }
    
    func handleEvent(_ event: MouseEvent) -> Bool {
        switch event {
        case .scrollWheel(_):
//            print("Scroll detected: deltaX = \(e.scrollingDeltaX), deltaY = \(e.scrollingDeltaY)")
            return true
        default:
            break
        }
        return false
    }
}

// 一个具体的鼠标拖拽 + 鼠标弹起的组合操作
class DragAndDropCombination: MouseEventCombination {
    let identifier: String
    private var dragEvents: [NSEvent] = []
    var onTrigger: (() -> Void)?

    private let dragThreshold: Int

    init(identifier: String = "DragAndDrop", dragThreshold: Int = 3) {
        self.identifier = identifier
        self.dragThreshold = dragThreshold
    }

    func handleEvent(_ event: MouseEvent) -> Bool {
        switch event {
        case .mouseDown:
            // 清空记录并记录按下事件
            dragEvents.removeAll()
        case .mouseDragged(let e):
            // 记录拖拽事件
            dragEvents.append(e)
        case .mouseUp:
            // 检查是否满足条件
            if dragEvents.count >= dragThreshold {
                return true
            }
        default:
            // 清空记录并记录按下事件
            dragEvents.removeAll()
        }
        return false
    }
}

// 自定义鼠标事件处理组合
class CustomMouseEventHandler: MouseEventCombination {
    let identifier: String
    private let handler: (MouseEvent) -> Bool
    var onTrigger: (() -> Void)? = nil
    
    init(identifier: String = "CustomMouseEvent", handler: @escaping (MouseEvent) -> Bool) {
        self.identifier = identifier
        self.handler = handler
    }
    
    func handleEvent(_ event: MouseEvent) -> Bool {
        return handler(event)
    }
}

