import Foundation

extension PreviewGenerator {
	/// Process meta information about the plugin. Like version and debug flag.
	mutating func procFooterInfo() {
		self.apply([
			"SrcAppName": "QLAppBundle",
			"SrcLinkUrl": "https://github.com/relikd/QLAppBundle",
			"SrcLinkName": "relikd/QLAppBundle",
			"SrcVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
			"SrcBuildVer": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
		])
#if DEBUG
		self.data["SrcAppName"]! += " (debug)"
#endif
	}
}
