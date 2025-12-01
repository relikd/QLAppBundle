import Foundation

extension PreviewGenerator {
	/// Search for app binary and run `codesign` on it.
	private func readEntitlements(_ meta: MetaInfo, _ bundleExecutable: String?) -> Entitlements {
		if let exe = bundleExecutable {
			switch meta.type {
			case .IPA:
				if let tmpPath = try? meta.zipFile!.unzipFileToTempDir("Payload/*.app/\(exe)") {
					defer {
						try? FileManager.default.removeItem(atPath: tmpPath)
					}
					return Entitlements(forBinary: tmpPath + "/" + exe)
				}
			case .Archive, .Extension:
				return Entitlements(forBinary: meta.effectiveUrl("MacOS", exe).path)
			case .APK:
				break // not applicable for Android
			}
		}
		return Entitlements.withoutBinary()
	}
	
	/// Process compiled binary and provision plist to extract `Entitlements`
	mutating func procEntitlements(_ meta: MetaInfo, _ appPlist: Plist_Info?, _ provisionPlist: Plist_MobileProvision?) {
		var entitlements = readEntitlements(meta, appPlist?.exePath)
		entitlements.applyFallbackIfNeeded(provisionPlist?.entitlements)
		
		if entitlements.html == nil && !entitlements.hasError {
			return
		}
		
		self.apply([
			"EntitlementsHidden" : CLASS_VISIBLE,
			"EntitlementsWarningHidden": entitlements.hasError ? CLASS_VISIBLE : CLASS_HIDDEN,
			"EntitlementsDict": entitlements.html ?? "No Entitlements",
		])
	}
}
