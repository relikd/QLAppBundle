import Cocoa
import Quartz // QLPreviewingController
import WebKit // WebView
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "preview-plugin")

class PreviewViewController: NSViewController, QLPreviewingController {
	
	override var nibName: NSNib.Name? {
		return NSNib.Name("PreviewViewController")
	}
	
	/// Load resource file either from user documents dir (if exists) or app bundle (default).
	func bundleFile(filename: String, ext: String) throws -> String {
		if let appSupport = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
			let override = appSupport.appendingPathComponent(filename + "." + ext)
			if FileManager.default.fileExists(atPath: override.path) {
				return try String(contentsOfFile: override.path, encoding: .utf8)
			}
			// else: do NOT copy! Breaks on future updates
		}
		// else, load bundle file
		let path = Bundle.main.url(forResource: filename, withExtension: ext)
		return try String(contentsOf: path!, encoding: .utf8)
	}
	
	func preparePreviewOfFile(at url: URL) async throws {
		let meta = MetaInfo(url)
		let html = HtmlGenerator(meta).generate(
			template: try bundleFile(filename: "template", ext: "html"),
			css: try bundleFile(filename: "style", ext: "css"),
		)
		// sure, we could use `WKWebView`, but that requires the `com.apple.security.network.client` entitlement
		//let web = WKWebView(frame: self.view.bounds)
		let web = WebView(frame: self.view.bounds)
		web.autoresizingMask = [.width, .height]
		self.view.addSubview(web)
		web.mainFrame.loadHTMLString(html, baseURL: nil)  // WebView
		//web.loadHTMLString(html, baseURL: nil)  // WKWebView
	}
}
