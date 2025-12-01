import Foundation

extension MetaInfo {
	/// Read `Info.plist`. (used for `PreviewProvider`)
	func readPlist_Info() -> Plist_Info? {
		if let x = self.readPayloadFile("Info.plist", osxSubdir: nil)?.asPlistOrNil() {
			return Plist_Info(x, isOSX: isOSX)
		}
		return nil
	}
}


// MARK: - Plist_Info

/// Representation of `Info.plist` of an `.ipa` bundle
struct Plist_Info {
	let bundleId: String?
	let name: String?
	let version: String?
	let buildVersion: String?
	
	let exePath: String?
	let sdkVersion: String?
	let minOS: String?
	let extensionType: String?
	
	let icons: [String]
	let deviceFamily: [String]
	let transportSecurity: PlistDict?
	
	init(_ plist: PlistDict, isOSX: Bool) {
		bundleId = plist["CFBundleIdentifier"] as? String
		name = plist["CFBundleDisplayName"] as? String ?? plist["CFBundleName"] as? String
		version = plist["CFBundleShortVersionString"] as? String
		buildVersion = plist["CFBundleVersion"] as? String
		exePath = plist["CFBundleExecutable"] as? String
		sdkVersion = plist["DTSDKName"] as? String
		minOS = plist[isOSX ? "LSMinimumSystemVersion" : "MinimumOSVersion"] as? String
		extensionType = (plist["NSExtension"] as? PlistDict)?["NSExtensionPointIdentifier"] as? String
		icons = Plist_Icon(plist).filenames
		deviceFamily = parseDeviceFamily(plist, isOSX: isOSX)
		transportSecurity = plist["NSAppTransportSecurity"] as? PlistDict
	}
}

private func parseDeviceFamily(_ plist: PlistDict, isOSX: Bool) -> [String] {
	if isOSX {
		return plist["CFBundleSupportedPlatforms"] as? [String] ?? ["macOS"]
	}
	
	if let platforms = (plist["UIDeviceFamily"] as? [Int])?.compactMap({
		switch $0 {
		case 1: "iPhone"
		case 2: "iPad"
		case 3: "TV"
		case 4: "Watch"
		default: nil
		}
	}), platforms.count > 0 {
		return platforms
	}
	
	if let minVersion = plist["MinimumOSVersion"] as? String {
		if minVersion.hasPrefix("1.") || minVersion.hasPrefix("2.") || minVersion.hasPrefix("3.") {
			return ["iPhone"]
		}
	}
	return []
}
