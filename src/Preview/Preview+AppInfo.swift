import Foundation

extension PreviewGenerator {
	/// Process info stored in `Info.plist`
	mutating func procAppInfoApple(_ appPlist: Plist_Info) {
		self.apply([
			"AppInfoHidden": CLASS_VISIBLE,
			"AppName": appPlist.name ?? "",
			"AppVersion": appPlist.version ?? "",
			"AppBuildVer": appPlist.buildVersion ?? "",
			"AppId": appPlist.bundleId ?? "",
			
			"AppExtensionTypeHidden": appPlist.extensionType != nil ? CLASS_VISIBLE : CLASS_HIDDEN,
			"AppExtensionType": appPlist.extensionType ?? "",
			
			"AppDeviceFamily": appPlist.deviceFamily.joined(separator: ", "),
			"AppSDK": appPlist.sdkVersion ?? "",
			"AppMinOS": appPlist.minOS ?? "",
		])
	}
	
	/// Process info stored in `AndroidManifest.xml`
	mutating func procAppInfoAndroid(_ manifest: Apk_Manifest) {
		let featReq = manifest.featuresRequired
		let featOpt = manifest.featuresOptional
		let perms = manifest.permissions
		
		func asList(_ list: [String]) -> String {
			"<pre>\(list.joined(separator: "\n"))</pre>"
		}
		
		func resolveSDK(_ sdk: Int?) -> String {
			sdk == nil ? "" : "\(sdk!) (Android \(AndroidSdkMap[sdk!] ?? "?"))"
		}
		self.apply([
			"AppInfoHidden": CLASS_VISIBLE,
			"AppName": manifest.appName ?? "",
			"AppVersion": manifest.versionName ?? "",
			"AppBuildVer": manifest.versionCode ?? "",
			"AppId": manifest.packageId ?? "",
			
			"ApkFeaturesRequiredHidden": featReq.isEmpty ? CLASS_HIDDEN : CLASS_VISIBLE,
			"ApkFeaturesRequiredList": asList(featReq),
			"ApkFeaturesOptionalHidden": featOpt.isEmpty ? CLASS_HIDDEN : CLASS_VISIBLE,
			"ApkFeaturesOptionalList": asList(featOpt),
			"ApkPermissionsHidden": perms.isEmpty ? CLASS_HIDDEN : CLASS_VISIBLE,
			"ApkPermissionsList": asList(perms),
			
			"AppDeviceFamily": "Android",
			"AppSDK": resolveSDK(manifest.sdkVerTarget),
			"AppMinOS": resolveSDK(manifest.sdkVerMin),
		])
	}
}

