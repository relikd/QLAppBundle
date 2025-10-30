import Cocoa
import Quartz // QLPreviewingController
import WebKit // WebView
import os // OSLog

// show Console logs with subsystem:de.relikd.QLAppBundle
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "preview-plugin")

class PreviewViewController: NSViewController, QLPreviewingController {
	
	override var nibName: NSNib.Name? {
		return NSNib.Name("PreviewViewController")
	}
	
	func preparePreviewOfFile(at url: URL) async throws {
		let meta = MetaInfo(url)
		let html = HtmlGenerator(meta).applyHtmlTemplate()
		// sure, we could use `WKWebView`, but that requires the `com.apple.security.network.client` entitlement
		//let web = WKWebView(frame: self.view.bounds)
		let web = WebView(frame: self.view.bounds)
		web.autoresizingMask = [.width, .height]
		self.view.addSubview(web)
		web.mainFrame.loadHTMLString(html, baseURL: nil)  // WebView
		//web.loadHTMLString(html, baseURL: nil)  // WKWebView
	}
}
