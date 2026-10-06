import Foundation
import UniformTypeIdentifiers
import WebKit

final class AppResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "sprig"

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard
            let url = urlSchemeTask.request.url,
            let fileURL = fileURL(for: url),
            let data = try? Data(contentsOf: fileURL),
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                "Content-Type": mimeType(for: fileURL),
                "Cache-Control": "no-store",
            ])
        else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private func fileURL(for url: URL) -> URL? {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("web", isDirectory: true).standardizedFileURL else {
            return nil
        }
        let file = root.appendingPathComponent(url.path).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/") else { return nil }
        return file
    }

    private func mimeType(for url: URL) -> String {
        // UTType has no MIME type for woff2
        if url.pathExtension == "woff2" { return "font/woff2" }
        return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
