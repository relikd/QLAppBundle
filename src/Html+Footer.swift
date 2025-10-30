import Foundation

extension HtmlGenerator {
	/// Process meta information about the plugin. Like version and debug flag.
	mutating func procFooterInfo() {
		self.apply([
			"SrcAppName": "QLAppBundle",
			"SrcLinkUrl": "https://github.com/relikd/QLAppBundle",
			"SrcLinkName": "relikd/QLAppBundle",
			"BundleShortVersionString": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
			"BundleVersion": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
		])
#if DEBUG
		self.data["SrcAppName"]! += " (debug)"
#endif
	}
}
