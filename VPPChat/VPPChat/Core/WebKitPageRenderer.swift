//
//  RenderedPage.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/20/25.
//


// VPPChat/Core/WebKitPageRenderer.swift

import Foundation
import WebKit

struct RenderedPage: Sendable {
  let finalURL: URL
  let title: String
  let html: String
  let text: String
}

@MainActor
final class WebKitPageRenderer: NSObject, WKNavigationDelegate {
  static let shared = WebKitPageRenderer()
    private var waitSelector: String?
    private var minSelectorTextChars: Int = 0
    private var waitBudgetSeconds: TimeInterval = 0
    private var extraWaitAfterReadyMs: UInt64 = 0
  private var webView: WKWebView?
  private var cont: CheckedContinuation<RenderedPage?, Never>?
  private var timeoutTask: Task<Void, Never>?

    func render(
      url: URL,
      timeout: TimeInterval = 10,
      waitForSelector: String? = "#root",
      minSelectorTextChars: Int = 600,
      waitBudgetSeconds: TimeInterval = 2.0,
      waitAfterReadyMs: UInt64 = 150,
      maxChars: Int = 30_000
    ) async -> RenderedPage? {
    // Serialize renders (simple + safe)
    if cont != nil { return nil }

    let cfg = WKWebViewConfiguration()
    cfg.websiteDataStore = .nonPersistent()

    let wv = WKWebView(frame: .zero, configuration: cfg)
    wv.navigationDelegate = self
    wv.setValue(false, forKey: "drawsBackground") // best-effort (harmless if ignored)
    self.webView = wv

    timeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
      guard let self, let cont = self.cont else { return }
      self.cont = nil
      cont.resume(returning: nil)
    }

    var req = URLRequest(url: url)
    req.timeoutInterval = timeout
        self.waitSelector = waitForSelector
        self.minSelectorTextChars = minSelectorTextChars
        self.waitBudgetSeconds = waitBudgetSeconds
        self.extraWaitAfterReadyMs = waitAfterReadyMs
    wv.load(req)

    return await withCheckedContinuation { (c: CheckedContinuation<RenderedPage?, Never>) in
      self.cont = c
    }.map { page in
      // clip here too, as a final guard
      RenderedPage(
        finalURL: page.finalURL,
        title: page.title,
        html: String(page.html.prefix(maxChars)),
        text: String(page.text.prefix(maxChars))
      )
    }
  }
    private func waitUntilReady(in webView: WKWebView) async {
      guard let sel = waitSelector, !sel.isEmpty else { return }

      let deadline = Date().addingTimeInterval(max(0, waitBudgetSeconds))
      let minChars = max(0, minSelectorTextChars)

      while Date() < deadline {
        let js = """
        (function(){
          const el = document.querySelector(\(String(reflecting: sel)));
          if (!el) return { exists:false, len:0 };
          const t = (el.innerText || el.textContent || "");
          return { exists:true, len:t.length };
        })();
        """
        do {
          if let obj = try await webView.evaluateJavaScript(js) as? [String: Any],
             let exists = obj["exists"] as? Bool,
             let len = obj["len"] as? Int {
            // Heuristic: selector exists OR selector has enough text (if minChars > 0)
            if exists && (minChars == 0 || len >= minChars) { break }
          }
        } catch {
          // ignore + keep polling
        }

        try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
      }

      if extraWaitAfterReadyMs > 0 {
        try? await Task.sleep(nanoseconds: extraWaitAfterReadyMs * 1_000_000)
      }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      Task { @MainActor [weak self] in
        guard let self else { return }

        // ✅ heuristic: wait for selector/text threshold (or time out)
        await waitUntilReady(in: webView)

        let js = """
        (function(){
          const title = document.title || "";
          const html = document.documentElement ? document.documentElement.outerHTML : "";
          const text = document.body ? document.body.innerText : "";
          return { title, html, text, href: location.href };
        })();
        """
        do {
          let any = try await webView.evaluateJavaScript(js)
          guard
            let obj = any as? [String: Any],
            let title = obj["title"] as? String,
            let html = obj["html"] as? String,
            let text = obj["text"] as? String,
            let href = obj["href"] as? String,
            let finalURL = URL(string: href)
          else {
            finish(nil)
            return
          }

          finish(RenderedPage(finalURL: finalURL, title: title, html: html, text: text))
        } catch {
          finish(nil)
        }
      }
    }

  private func finish(_ page: RenderedPage?) {
    timeoutTask?.cancel()
    timeoutTask = nil

    let c = cont
    cont = nil
    webView?.navigationDelegate = nil
    webView = nil

    c?.resume(returning: page)
  }
}
