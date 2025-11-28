import Foundation

private let TransportSecurityLocalizedKeys = [
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
private func recursiveTransportSecurity(_ dictionary: PlistDict, _ level: Int = 0) -> String {
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
	/// Process ATS info in `Info.plist`
	mutating func procTransportSecurity(_ appPlist: PlistDict?) {
		guard let value = appPlist?["NSAppTransportSecurity"] as? PlistDict else {
			return
		}
		
		self.apply([
			"TransportSecurityHidden": CLASS_VISIBLE,
			"TransportSecurityDict": "<div class=\"list\">\(recursiveTransportSecurity(value))</div>",
		])
	}
}
