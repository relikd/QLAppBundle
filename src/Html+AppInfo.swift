import Foundation

/// Print recursive tree of key-value mappings.
private func recursiveDict(_ dictionary: [String: Any], withReplacements replacements: [String: String] = [:], _ level: Int = 0) -> String {
	var output = ""
	for (key, value) in dictionary {
		let localizedKey = replacements[key] ?? key
		for _ in 0..<level {
			output += (level == 1) ? "- " : "&nbsp;&nbsp;"
		}
		
		if let subDict = value as? [String: Any] {
			output += "\(localizedKey):<div class=\"list\">\n"
			output += recursiveDict(subDict, withReplacements: replacements, level + 1)
			output += "</div>\n"
		} else if let number = value as? NSNumber {
			output += "\(localizedKey): \(number.boolValue ? "YES" : "NO")<br />"
		} else {
			output += "\(localizedKey): \(value)<br />"
		}
	}
	return output
}

extension HtmlGenerator {
	/// @return List of ATS flags.
	private func formattedAppTransportSecurity(_ appPlist: PlistDict) -> String {
		if let value = appPlist["NSAppTransportSecurity"] as? PlistDict {
			let localizedKeys = [
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
			
			return "<div class=\"list\">\(recursiveDict(value, withReplacements: localizedKeys))</div>"
		}
		
		let sdkName = appPlist["DTSDKName"] as? String ?? "0"
		let sdkNumber = Double(sdkName.trimmingCharacters(in: .letters)) ?? 0
		if sdkNumber < 9.0 {
			return "Not applicable before iOS 9.0"
		}
		return "No exceptions"
	}
	
	/// Process info stored in `Info.plist`
	mutating func procAppInfo(_ appPlist: PlistDict?) {
		guard let appPlist else {
			self.apply([
				"AppInfoHidden": "hiddenDiv",
				"ProvisionTitleHidden": "",
			])
			return
		}
		
		var platforms = (appPlist["UIDeviceFamily"] as? [Int])?.compactMap({
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
			platforms = "iPhone"
		}
		
		let extensionType = (appPlist["NSExtension"] as? PlistDict)?["NSExtensionPointIdentifier"] as? String
		self.apply([
			"AppInfoHidden": "",
			"ProvisionTitleHidden": "hiddenDiv",
			
			"CFBundleName": appPlist["CFBundleDisplayName"] as? String ?? appPlist["CFBundleName"] as? String ?? "",
			"CFBundleShortVersionString": appPlist["CFBundleShortVersionString"] as? String ?? "",
			"CFBundleVersion": appPlist["CFBundleVersion"] as? String ?? "",
			"CFBundleIdentifier": appPlist["CFBundleIdentifier"] as? String ?? "",
			
			"ExtensionTypeHidden": extensionType != nil ? "" : "hiddenDiv",
			"ExtensionType": extensionType ?? "",
			
			"UIDeviceFamily": platforms ?? "",
			"DTSDKName": appPlist["DTSDKName"] as? String ?? "",
			"MinimumOSVersion": minVersion,
			"AppTransportSecurityFormatted": formattedAppTransportSecurity(appPlist),
		])
	}
}
