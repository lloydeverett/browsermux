//
//  BrowserMuxApp.swift
//  BrowserMux
//
//  Created by Lloyd Everett on 2025/09/07.
//

import Foundation
import NIO
import NIOPosix
import SwiftUI

@main
struct BrowserMuxApp: App {
    let group: any EventLoopGroup

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    cleanup()
                }
        }
    }

    init() {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let _ = try! asyncManageControlSocket(group: group, handler: EchoHandler())
    }
    func cleanup() {
        try! group.syncShutdownGracefully()
    }
}
