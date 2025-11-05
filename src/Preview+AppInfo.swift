import Foundation

extension PreviewGenerator {
	private func deviceFamilyList(_ appPlist: PlistDict, isOSX: Bool) -> String {
		if isOSX {
			return (appPlist["CFBundleSupportedPlatforms"] as? [String])?.joined(separator: ", ") ?? "macOS"
		}
		let platforms = (appPlist["UIDeviceFamily"] as? [Int])?.compactMap({
			switch $0 {
			case 1: return "iPhone"
			case 2: return "iPad"
			case 3: return "TV"
			case 4: return "Watch"
			default: return nil
			}
		}).joined(separator: ", ")
		
		let minVersion = appPlist["MinimumOSVersion"] as? String ?? ""
		if platforms?.isEmpty ?? true, minVersion.hasPrefix("1.") || minVersion.hasPrefix("2.") || minVersion.hasPrefix("3.") {
			return "iPhone"
		}
		return platforms ?? ""
	}
	
	/// Process info stored in `Info.plist`
	mutating func procAppInfo(_ appPlist: PlistDict?, isOSX: Bool) {
		guard let appPlist else {
			self.apply(["AppInfoHidden": CLASS_HIDDEN])
			return
		}
		let minVersion = appPlist[isOSX ? "LSMinimumSystemVersion" : "MinimumOSVersion"] as? String ?? ""
		
		let extensionType = (appPlist["NSExtension"] as? PlistDict)?["NSExtensionPointIdentifier"] as? String
		self.apply([
			"AppInfoHidden": CLASS_VISIBLE,
			"AppName": appPlist["CFBundleDisplayName"] as? String ?? appPlist["CFBundleName"] as? String ?? "",
			"AppVersion": appPlist["CFBundleShortVersionString"] as? String ?? "",
			"AppBuildVer": appPlist["CFBundleVersion"] as? String ?? "",
			"AppId": appPlist["CFBundleIdentifier"] as? String ?? "",
			
			"AppExtensionTypeHidden": extensionType != nil ? CLASS_VISIBLE : CLASS_HIDDEN,
			"AppExtensionType": extensionType ?? "",
			
			"AppDeviceFamily": deviceFamilyList(appPlist, isOSX: isOSX),
			"AppSDK": appPlist["DTSDKName"] as? String ?? "",
			"AppMinOS": minVersion,
		])
	}
}
