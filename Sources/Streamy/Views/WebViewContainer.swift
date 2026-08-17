import SwiftUI
import WebKit
import AppKit

public struct WebViewContainer: NSViewRepresentable {
    @ObservedObject var model: StreamyModel
    
    public init(model: StreamyModel) {
        self.model = model
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Shared persistent process pool to retain logins across app launches
    private static let sharedProcessPool = WKProcessPool()

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = Self.sharedProcessPool
        configuration.websiteDataStore = WKWebsiteDataStore.default() // Persistent cookies, sessions, and auth
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webPreferences = WKPreferences()
        webPreferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = webPreferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Dark background to prevent bright flash
        webView.setValue(false, forKey: "drawsBackground")
        webView.layer?.backgroundColor = NSColor.black.cgColor
        
        // Desktop Safari User Agent for login compatibility (Google/YouTube, Twitch, Netflix)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

        
        if let url = URL(string: formattedURL(model.currentURL)) {
            webView.load(URLRequest(url: url))
        }
        
        context.coordinator.webView = webView
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.currentLoadedURL != model.currentURL {
            context.coordinator.currentLoadedURL = model.currentURL
            if let url = URL(string: formattedURL(model.currentURL)) {
                nsView.load(URLRequest(url: url))
            }
        }
    }
    
    private func formattedURL(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        if trimmed.contains(".") && !trimmed.contains(" ") {
            return "https://" + trimmed
        }
        // Fallback search query on YouTube or Google if not a direct URL
        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return "https://www.youtube.com/results?search_query=\(encoded)"
        }
        return "https://www.youtube.com"
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        var currentLoadedURL: String = ""
        weak var webView: WKWebView?
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
            self.currentLoadedURL = parent.model.currentURL
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let urlString = webView.url?.absoluteString, urlString != parent.model.currentURL {
                DispatchQueue.main.async {
                    self.parent.model.currentURL = urlString
                    self.currentLoadedURL = urlString
                }
            }
        }
        
        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Open target=_blank in same webview
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
