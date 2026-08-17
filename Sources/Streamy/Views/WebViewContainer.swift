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
        
        let contentController = WKUserContentController()
        let js = """
            (function() {
                try {
                    if (!('fullscreenEnabled' in document)) {
                        Object.defineProperty(document, 'fullscreenEnabled', { value: true, writable: true });
                    }
                    if (!('webkitFullscreenEnabled' in document)) {
                        Object.defineProperty(document, 'webkitFullscreenEnabled', { value: true, writable: true });
                    }
                    
                    var style = document.createElement('style');
                    style.id = 'streamy-fullscreen-style';
                    style.textContent = `
                        body.streamy-inner-fullscreen {
                            overflow: hidden !important;
                        }
                        body.streamy-inner-fullscreen #movie_player,
                        body.streamy-inner-fullscreen .html5-video-player,
                        body.streamy-inner-fullscreen .video-js {
                            position: fixed !important;
                            top: 0 !important;
                            left: 0 !important;
                            width: 100vw !important;
                            height: 100vh !important;
                            z-index: 2147483647 !important;
                            background: #000 !important;
                        }
                        body.streamy-inner-fullscreen video {
                            width: 100vw !important;
                            height: 100vh !important;
                            object-fit: contain !important;
                        }
                    `;
                    if (document.head && !document.getElementById('streamy-fullscreen-style')) {
                        document.head.appendChild(style);
                    }
                    
                    function toggleInnerFullscreen() {
                        var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player') || document.querySelector('video');
                        var isFS = document.body.classList.contains('streamy-inner-fullscreen');
                        if (!isFS) {
                            document.body.classList.add('streamy-inner-fullscreen');
                            if (player) player.classList.add('ytp-fullscreen');
                        } else {
                            document.body.classList.remove('streamy-inner-fullscreen');
                            if (player) player.classList.remove('ytp-fullscreen');
                        }
                    }
                    
                    document.addEventListener('click', function(e) {
                        var btn = e.target.closest('.ytp-fullscreen-button');
                        if (btn) {
                            e.preventDefault();
                            e.stopPropagation();
                            toggleInnerFullscreen();
                        }
                    }, true);
                    
                    Element.prototype.requestFullscreen = function() {
                        toggleInnerFullscreen();
                        return Promise.resolve();
                    };
                    if (!Element.prototype.webkitRequestFullscreen) {
                        Element.prototype.webkitRequestFullscreen = Element.prototype.requestFullscreen;
                    }
                    document.exitFullscreen = function() {
                        document.body.classList.remove('streamy-inner-fullscreen');
                        var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                        if (player) player.classList.remove('ytp-fullscreen');
                        return Promise.resolve();
                    };
                    if (!document.webkitExitFullscreen) {
                        document.webkitExitFullscreen = document.exitFullscreen;
                    }
                } catch(e) {}
            })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        configuration.userContentController = contentController
        
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
            if let urlString = webView.url?.absoluteString {
                let pageTitle = webView.title ?? ""
                DispatchQueue.main.async {
                    if urlString != self.parent.model.currentURL {
                        self.parent.model.currentURL = urlString
                        self.currentLoadedURL = urlString
                    }
                    self.parent.model.recordWatchHistory(title: pageTitle, urlString: urlString)
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
