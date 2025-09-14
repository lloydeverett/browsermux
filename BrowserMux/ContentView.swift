//
//  ContentView.swift
//  BrowserMux
//
//  Created by Lloyd Everett on 2025/09/07.
//

import Foundation
import SwiftUI
import WebKit
import SwiftTerm

func createWebView(url: URL) -> WKWebView {
    let webView = WKWebView()
    webView.load(URLRequest(url: url))
    return webView
}

struct TermView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = LocalProcessTerminalView(frame: .zero)

        let shellPath: String
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            shellPath = shell
        } else {
            shellPath = "/bin/zsh"
        }
        view.startProcess(executable: shellPath, args: ["-l"])

        return view
    }

    func updateNSView(_ uiView: NSView, context: Context) {
    }
}

struct WebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        return webView
    }

    func updateNSView(_ uiView: WKWebView, context: Context) {
    }
}

struct ContentView: View {
    @State private var webView: WKWebView = createWebView(url: URL(string: "https://google.com/")!)

    var body: some View {
        HStack {
            WebView(webView: webView).edgesIgnoringSafeArea(.all)
            TermView()
        }
    }
}

#Preview {
    ContentView()
}

