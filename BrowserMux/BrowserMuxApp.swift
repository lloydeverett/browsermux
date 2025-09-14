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
import Cocoa

struct PresentableError: Error {
    let messageText: String
    let informativeText: String
    let innerError: any Error
}

@MainActor
func presentError(err: PresentableError) {
    print("fatal error: \(err.innerError)")
    let alert = NSAlert()
    alert.messageText = err.messageText
    alert.informativeText = err.informativeText
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    let _ = alert.runModal()
}

@main
struct BrowserMuxApp: App {
    let group: any EventLoopGroup

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 400)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    cleanup()
                }
        }
    }

    init() {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let promise: EventLoopFuture<Void>
        do {
            promise = try listenOnControlSocket(group: group, handler: HTTPHandler())
        } catch {
            presentError(err: error)
            exit(EXIT_FAILURE)
        }
        promise.whenFailure({ err in
            Task {
                await presentError(err:
                    PresentableError(
                        messageText: "Failed to listen for control instructions",
                        informativeText: "An unexpected error occurred while listening for control instructions. You may need to restart the application to ensure proper functioning. Additional technical details have been printed to the console.",
                        innerError: err)
                )
            }
        })
    }

    func cleanup() {
        try! group.syncShutdownGracefully()
    }
}
