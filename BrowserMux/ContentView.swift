//
//  ContentView.swift
//  BrowserMux
//
//  Created by Lloyd Everett on 2025/09/07.
//

import SwiftUI
import WebKit

func createWebView(url: URL) -> WKWebView {
    let webView = WKWebView()
    webView.load(URLRequest(url: url))
    return webView
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
        WebView(webView: webView)
            .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ContentView()
}

