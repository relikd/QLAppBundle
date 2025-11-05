import Foundation

extension PreviewGenerator {
	/// Search for app binary and run `codesign` on it.
	private func readEntitlements(_ meta: MetaInfo, _ bundleExecutable: String?) -> Entitlements {
		guard let bundleExecutable else {
			return Entitlements.withoutBinary()
		}
		
		switch meta.type {
		case .IPA:
			let tmpPath = NSTemporaryDirectory() + "/" + UUID().uuidString
			try! FileManager.default.createDirectory(atPath: tmpPath, withIntermediateDirectories: true)
			defer {
				try? FileManager.default.removeItem(atPath: tmpPath)
			}
			try! meta.zipFile!.unzipFile("Payload/*.app/\(bundleExecutable)", toDir: tmpPath)
			return Entitlements(forBinary: tmpPath + "/" + bundleExecutable)
		case .Archive, .Extension:
			return Entitlements(forBinary: meta.effectiveUrl("MacOS", bundleExecutable).path)
		}
	}
	
	/// Process compiled binary and provision plist to extract `Entitlements`
	mutating func procEntitlements(_ meta: MetaInfo, _ appPlist: PlistDict?, _ provisionPlist: PlistDict?) {
		var entitlements = readEntitlements(meta, appPlist?["CFBundleExecutable"] as? String)
		entitlements.applyFallbackIfNeeded(provisionPlist?["Entitlements"] as? PlistDict)
		
		if entitlements.html == nil && !entitlements.hasError {
			self.apply(["EntitlementsHidden" : CLASS_HIDDEN])
			return
		}
		
		self.apply([
			"EntitlementsHidden" : CLASS_VISIBLE,
			"EntitlementsWarningHidden": entitlements.hasError ? CLASS_VISIBLE : CLASS_HIDDEN,
			"EntitlementsDict": entitlements.html ?? "No Entitlements",
		])
	}
}
