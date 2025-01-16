//
//  Logger.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/9.
//

import Foundation
import os.log

struct Logger {
    static let shared = Logger()
    private let log: OSLog

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.openagi.xpop"
        log = OSLog(subsystem: subsystem, category: "general")
    }

    func log(
        _ message: StaticString,
        dso: UnsafeRawPointer? = #dsohandle,
        _ args: CVarArg...,
        type: OSLogType = .default
    ) {
        os_log(message, dso: dso, log: log, type: type, args)
    }
}
