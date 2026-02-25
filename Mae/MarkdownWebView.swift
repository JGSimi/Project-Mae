//
//  MarkdownWebView.swift
//  Mae
//
//  Created by Joao Simi on 25/02/26.
//

import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = buildHTML(from: markdown)
        webView.loadHTMLString(html, baseURL: nil)
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
        </script>
        </body>
        </html>
        """
    }
}
