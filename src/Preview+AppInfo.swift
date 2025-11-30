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
	
	/// Process info stored in `Info.plist`
	mutating func procAppInfoAndroid(_ manifest: ApkManifest) {
		let featReq = manifest.featuresRequired
		let featOpt = manifest.featuresOptional
		let perms = manifest.permissions
		
		func asList(_ list: [String]) -> String {
			"<pre>\(list.joined(separator: "\n"))</pre>"
		}
		
		func resolveSDK(_ sdk: String?) -> String {
			sdk == nil ? "" : "\(sdk!) (Android \(ANDROID_SDK_MAP[sdk!] ?? "?"))"
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

private let ANDROID_SDK_MAP: [String: String] = [
	"1": "1.0",
	"2": "1.1",
	"3": "1.5",
	"4": "1.6",
	"5": "2.0",
	"6": "2.0.1",
	"7": "2.1.x",
	"8": "2.2.x",
	"9": "2.3, 2.3.1, 2.3.2",
	"10": "2.3.3, 2.3.4",
	"11": "3.0.x",
	"12": "3.1.x",
	"13": "3.2",
	"14": "4.0, 4.0.1, 4.0.2",
	"15": "4.0.3, 4.0.4",
	"16": "4.1, 4.1.1",
	"17": "4.2, 4.2.2",
	"18": "4.3",
	"19": "4.4",
	"20": "4.4W",
	"21": "5.0",
	"22": "5.1",
	"23": "6.0",
	"24": "7.0",
	"25": "7.1, 7.1.1",
	"26": "8.0",
	"27": "8.1",
	"28": "9",
	"29": "10",
	"30": "11",
	"31": "12",
	"32": "12",
	"33": "13",
	"34": "14",
	"35": "15",
	"36": "16",
	// can we assume new versions will stick to this scheme?
	"37": "17",
	"38": "18",
	"39": "19",
	"40": "20",
]
