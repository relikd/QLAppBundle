import Foundation

let TransportSecurityLocalizedKeys = [
	"NSAllowsArbitraryLoads": "Allows Arbitrary Loads",
	"NSAllowsArbitraryLoadsForMedia": "Allows Arbitrary Loads for Media",
	"NSAllowsArbitraryLoadsInWebContent": "Allows Arbitrary Loads in Web Content",
	"NSAllowsLocalNetworking": "Allows Local Networking",
	"NSExceptionDomains": "Exception Domains",
	
	"NSIncludesSubdomains": "Includes Subdomains",
	"NSRequiresCertificateTransparency": "Requires Certificate Transparency",
	
	"NSExceptionAllowsInsecureHTTPLoads": "Allows Insecure HTTP Loads",
	"NSExceptionMinimumTLSVersion": "Minimum TLS Version",
	"NSExceptionRequiresForwardSecrecy": "Requires Forward Secrecy",
	
	"NSThirdPartyExceptionAllowsInsecureHTTPLoads": "Allows Insecure HTTP Loads",
	"NSThirdPartyExceptionMinimumTLSVersion": "Minimum TLS Version",
	"NSThirdPartyExceptionRequiresForwardSecrecy": "Requires Forward Secrecy",
]

/// Print recursive tree of key-value mappings.
private func recursiveTransportSecurity(_ dictionary: [String: Any], _ level: Int = 0) -> String {
	var output = ""
	for (key, value) in dictionary {
		let localizedKey = TransportSecurityLocalizedKeys[key] ?? key
		for _ in 0..<level {
			output += (level == 1) ? "- " : "&nbsp;&nbsp;"
		}
		
		if let subDict = value as? [String: Any] {
			output += "\(localizedKey):<div class=\"list\">\n"
			output += recursiveTransportSecurity(subDict, level + 1)
			output += "</div>\n"
		} else if let number = value as? NSNumber {
			output += "\(localizedKey): \(number.boolValue ? "YES" : "NO")<br />"
		} else {
			output += "\(localizedKey): \(value)<br />"
		}
	}
	return output
}

extension PreviewGenerator {
	/// @return List of ATS flags.
	private func formattedAppTransportSecurity(_ appPlist: PlistDict) -> String {
		if let value = appPlist["NSAppTransportSecurity"] as? PlistDict {
			return "<div class=\"list\">\(recursiveTransportSecurity(value))</div>"
		}
		
		let sdkName = appPlist["DTSDKName"] as? String ?? "0"
		let sdkNumber = Double(sdkName.trimmingCharacters(in: .letters)) ?? 0
		if sdkNumber < 9.0 {
			return "Not applicable before iOS 9.0"
		}
		return "No exceptions"
	}
	
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
	mutating func procAppInfo(_ appPlist: PlistDict, isOSX: Bool) {
		let minVersion = appPlist[isOSX ? "LSMinimumSystemVersion" : "MinimumOSVersion"] as? String ?? ""
		
		let extensionType = (appPlist["NSExtension"] as? PlistDict)?["NSExtensionPointIdentifier"] as? String
		self.apply([
			"AppName": appPlist["CFBundleDisplayName"] as? String ?? appPlist["CFBundleName"] as? String ?? "",
			"AppVersion": appPlist["CFBundleShortVersionString"] as? String ?? "",
			"AppBuildVer": appPlist["CFBundleVersion"] as? String ?? "",
			"AppId": appPlist["CFBundleIdentifier"] as? String ?? "",
			
			"AppExtensionTypeHidden": extensionType != nil ? "" : CLASS_HIDDEN,
			"AppExtensionType": extensionType ?? "",
			
			"AppDeviceFamily": deviceFamilyList(appPlist, isOSX: isOSX),
			"AppSDK": appPlist["DTSDKName"] as? String ?? "",
			"AppMinOS": minVersion,
			"AppTransportSecurity": formattedAppTransportSecurity(appPlist),
		])
	}
}
