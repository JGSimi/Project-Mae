//
//  MarkdownWebView.swift
//  Mae
//
//  Created by Joao Simi on 25/02/26.
//

import SwiftUI
import WebKit

/// WKWebView subclass that forwards scroll events to the parent responder,
/// allowing SwiftUI ScrollViews to scroll even when the mouse is over the WebView.
class NonScrollingWKWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        // Forward scroll events to next responder (parent scroll view)
        nextResponder?.scrollWheel(with: event)
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    
    @State private var contentHeight: CGFloat = 40
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightChanged")
        
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        
        let webView = NonScrollingWKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        
        let html = buildHTML(from: markdown)
        context.coordinator.lastMarkdown = markdown
        webView.loadHTMLString(html, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload if markdown actually changed
        if context.coordinator.lastMarkdown != markdown {
            context.coordinator.lastMarkdown = markdown
            let html = buildHTML(from: markdown)
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownWebView
        var lastMarkdown: String = ""
        weak var webView: WKWebView?
        
        init(parent: MarkdownWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measureHeight(webView)
        }
        
        private func measureHeight(_ webView: WKWebView) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self?.parent.contentHeight = height
                    }
                }
            }
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged", let height = message.body as? CGFloat, height > 0 {
                DispatchQueue.main.async {
                    self.parent.contentHeight = height
                }
            }
        }
    }
    
    // Expose the measured height to parent via a preference or frame
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WKWebView, context: Context) -> CGSize? {
        // Return intrinsic content height, but respect proposed width
        return CGSize(width: proposal.width ?? 300, height: contentHeight)
    }
    
    private func buildHTML(from markdown: String) -> String {
        // Escape the markdown for safe JS string embedding
        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
        
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', sans-serif;
                font-size: 14px;
                line-height: 1.65;
                color: rgba(255, 255, 255, 0.92);
                background: transparent;
                padding: 8px 0;
                -webkit-font-smoothing: antialiased;
                font-weight: 400;
                letter-spacing: -0.01em;
            }
        
            h1, h2, h3, h4, h5, h6 {
                font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', sans-serif;
                font-weight: 600;
                color: #ffffff;
                margin-top: 20px;
                margin-bottom: 8px;
                line-height: 1.35;
                letter-spacing: -0.02em;
            }
        
            h1 { font-size: 24px; font-weight: 700; }
            h2 { font-size: 20px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 6px; }
            h3 { font-size: 16px; font-weight: 600; }
            h4 { font-size: 14px; font-weight: 600; }
        
            p {
                margin-bottom: 12px;
            }
        
            strong {
                font-weight: 700;
                color: #ffffff;
            }
        
            em {
                font-style: italic;
            }
        
            a {
                color: #6cb4ee;
                text-decoration: none;
            }
            a:hover {
                text-decoration: underline;
            }
        
            ul, ol {
                margin-bottom: 12px;
                padding-left: 24px;
            }
        
            li {
                margin-bottom: 4px;
            }
        
            li > ul, li > ol {
                margin-top: 4px;
                margin-bottom: 4px;
            }
        
            hr {
                border: none;
                border-top: 1px solid rgba(255, 255, 255, 0.15);
                margin: 16px 0;
            }
        
            code {
                font-family: 'SF Mono', 'Menlo', 'Monaco', monospace;
                font-size: 13px;
                background: rgba(255, 255, 255, 0.08);
                padding: 2px 6px;
                border-radius: 4px;
                color: #e8e8e8;
            }
        
            pre {
                background: rgba(255, 255, 255, 0.06);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 8px;
                padding: 12px 16px;
                margin-bottom: 12px;
                overflow-x: auto;
            }
        
            pre code {
                background: none;
                padding: 0;
                font-size: 13px;
                line-height: 1.5;
            }
        
            blockquote {
                border-left: 3px solid rgba(255, 255, 255, 0.25);
                padding-left: 14px;
                margin-bottom: 12px;
                color: rgba(255, 255, 255, 0.7);
                font-style: italic;
            }
        
            table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 12px;
            }
        
            th, td {
                border: 1px solid rgba(255, 255, 255, 0.12);
                padding: 8px 12px;
                text-align: left;
            }
        
            th {
                background: rgba(255, 255, 255, 0.06);
                font-weight: 600;
            }
        
            /* Remove margin from first/last elements */
            :first-child { margin-top: 0; }
            :last-child { margin-bottom: 0; }
        </style>
        <!-- marked.js CDN - lightweight markdown parser -->
        <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
        </head>
        <body>
        <div id="content"></div>
        <script>
            const md = `\(escapedMarkdown)`;
            document.getElementById('content').innerHTML = marked.parse(md);
        
            function notifyHeight() {
                const el = document.getElementById('content');
                if (!el) return;
                const h = el.offsetHeight;
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged) {
                    window.webkit.messageHandlers.heightChanged.postMessage(h);
                }
            }
        
            const ro = new ResizeObserver(() => notifyHeight());
            ro.observe(document.getElementById('content'));
            
            document.querySelectorAll('img').forEach(img => {
                img.addEventListener('load', notifyHeight);
            });
            
            window.addEventListener('load', notifyHeight);
            setTimeout(notifyHeight, 100);
            setTimeout(notifyHeight, 500);
        </script>
        </body>
        </html>
        """
    }
}

/// A version of MarkdownWebView that auto-resizes to fit its content,
/// suitable for embedding inside ScrollViews and chat bubbles.
struct AutoSizingMarkdownWebView: NSViewRepresentable {
    let markdown: String
    @Binding var measuredHeight: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightChanged")
        
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        
        let webView = NonScrollingWKWebView(frame: NSRect(x: 0, y: 0, width: 300, height: 40), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        
        let html = buildHTML(from: markdown)
        context.coordinator.lastMarkdown = markdown
        webView.loadHTMLString(html, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastMarkdown != markdown {
            context.coordinator.lastMarkdown = markdown
            let html = buildHTML(from: markdown)
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: AutoSizingMarkdownWebView
        var lastMarkdown: String = ""
        weak var webView: WKWebView?
        
        init(parent: AutoSizingMarkdownWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measureHeight(webView)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged", let height = message.body as? CGFloat, height > 0 {
                DispatchQueue.main.async {
                    self.parent.measuredHeight = height + 4 // small padding
                }
            }
        }
        
        func measureHeight(_ webView: WKWebView) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self?.parent.measuredHeight = height + 4
                    }
                }
            }
        }
    }
    
    private func buildHTML(from markdown: String) -> String {
        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
        
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', sans-serif;
                font-size: 13px;
                line-height: 1.6;
                color: rgba(255, 255, 255, 0.92);
                background: transparent;
                padding: 4px 0;
                -webkit-font-smoothing: antialiased;
                font-weight: 400;
                letter-spacing: -0.01em;
                overflow: hidden;
            }
        
            h1, h2, h3, h4, h5, h6 {
                font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', sans-serif;
                font-weight: 600;
                color: #ffffff;
                margin-top: 14px;
                margin-bottom: 6px;
                line-height: 1.3;
                letter-spacing: -0.02em;
            }
        
            h1 { font-size: 20px; font-weight: 700; }
            h2 { font-size: 17px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 4px; }
            h3 { font-size: 15px; font-weight: 600; }
            h4 { font-size: 13px; font-weight: 600; }
        
            p {
                margin-bottom: 10px;
            }
        
            strong {
                font-weight: 700;
                color: #ffffff;
            }
        
            em {
                font-style: italic;
            }
        
            a {
                color: #6cb4ee;
                text-decoration: none;
            }
            a:hover {
                text-decoration: underline;
            }
        
            ul, ol {
                margin-bottom: 10px;
                padding-left: 22px;
            }
        
            li {
                margin-bottom: 3px;
            }
        
            li > ul, li > ol {
                margin-top: 3px;
                margin-bottom: 3px;
            }
        
            hr {
                border: none;
                border-top: 1px solid rgba(255, 255, 255, 0.15);
                margin: 12px 0;
            }
        
            code {
                font-family: 'SF Mono', 'Menlo', 'Monaco', monospace;
                font-size: 12px;
                background: rgba(255, 255, 255, 0.08);
                padding: 2px 5px;
                border-radius: 4px;
                color: #e8e8e8;
            }
        
            pre {
                background: rgba(255, 255, 255, 0.06);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 8px;
                padding: 10px 14px;
                margin-bottom: 10px;
                overflow-x: auto;
            }
        
            pre code {
                background: none;
                padding: 0;
                font-size: 12px;
                line-height: 1.45;
            }
        
            blockquote {
                border-left: 3px solid rgba(255, 255, 255, 0.25);
                padding-left: 12px;
                margin-bottom: 10px;
                color: rgba(255, 255, 255, 0.7);
                font-style: italic;
            }
        
            table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 10px;
            }
        
            th, td {
                border: 1px solid rgba(255, 255, 255, 0.12);
                padding: 6px 10px;
                text-align: left;
                font-size: 12px;
            }
        
            th {
                background: rgba(255, 255, 255, 0.06);
                font-weight: 600;
            }
        
            :first-child { margin-top: 0; }
            :last-child { margin-bottom: 0; }
        </style>
        <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
        </head>
        <body>
        <div id="content"></div>
        <script>
            const md = `\(escapedMarkdown)`;
            document.getElementById('content').innerHTML = marked.parse(md);
        
            function notifyHeight() {
                const el = document.getElementById('content');
                if (!el) return;
                const h = el.offsetHeight;
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged && h > 0) {
                    window.webkit.messageHandlers.heightChanged.postMessage(h);
                }
            }
        
            const ro = new ResizeObserver(() => notifyHeight());
            ro.observe(document.getElementById('content'));
        
            document.querySelectorAll('img').forEach(img => {
                img.addEventListener('load', notifyHeight);
            });
        
            window.addEventListener('load', notifyHeight);
            setTimeout(notifyHeight, 100);
            setTimeout(notifyHeight, 500);
        </script>
        </body>
        </html>
        """
    }
}
