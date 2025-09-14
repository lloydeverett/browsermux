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

struct BrowserView: View {
    @Binding var text: String
    @Binding var webView: WKWebView

    var body: some View {
        VSplitView {
            TextEditor(text: $text).font(.system(size: 17, design: .monospaced)).border(Color.gray, width: 0)
            WebView(webView: webView).edgesIgnoringSafeArea(.all)
        }
    }
}

struct MainTree : View {
    @State private var text: String = ""
    @State private var key: String = UUID().uuidString
    @State private var webView: WKWebView = createWebView(url: URL(string: "https://example.com/")!)

    var body: some View {
        BrowserView(text: $text, webView: $webView)
    }
}

struct AltTree : View {
    @State private var key: String = UUID().uuidString
    @State private var webView: WKWebView = createWebView(url: URL(string: "https://google.com/")!)
    @State private var text: String = """
    > x should correspond to browser tab x on the right
    maybe support external windows too
    """

    var body: some View {
        HSplitView() {
            TextEditor(text: $text)
                .font(.system(size: 17, design: .monospaced))
                .border(Color.gray, width: 0)
                .frame(minWidth: 200, maxWidth: 600)
            WebView(webView: webView)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct Settings: View {
    @State private var text: String = """
    // usage: you can call this to "google" text or "search" the web in any way
    function google(query) {
        // ... do stuff ...
    }
    """

    var body: some View {
        TextEditor(text: $text).font(.system(size: 17, design: .monospaced)).border(Color.gray, width: 0)
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            MainTree()
                .tabItem {
                    Label("Vibe Coder", systemImage: "house")
                }
            AltTree()
                .tabItem {
                    Label("Vibe Browser", systemImage: "house")
                }
            Settings()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}

