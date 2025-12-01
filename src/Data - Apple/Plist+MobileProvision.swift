import Foundation

extension MetaInfo {
	/// Read `embedded.mobileprovision` (if available) and decode with CMS decoder.
	func readPlist_MobileProvision() -> Plist_MobileProvision? {
		guard let provisionData = self.readPayloadFile("embedded.mobileprovision", osxSubdir: nil),
			  let plist = provisionData.decodeCMS().asPlistOrNil() else {
			return nil
		}
		return Plist_MobileProvision(plist, isOSX: self.isOSX)
	}
}

// MARK: - Plist_MobileProvision

/// Representation of `embedded.mobileprovision`
struct Plist_MobileProvision {
	let creationDate: Date?
	let expireDate: Date?
	let profileId: String?
	let profileName: String?
	/// Something like "Development" or "Distribution (App Store)".
	let profileType: String
	/// Either "Mac" or "iOS"
	let profilePlatform: String
	let teamName: String?
	let teamIds: [String]
	let devices: [String]
	let certificates: [ProvisioningCertificate]
	let entitlements: PlistDict?
	
	init(_ plist: PlistDict, isOSX: Bool) {
		creationDate = plist["CreationDate"] as? Date
		expireDate = plist["ExpirationDate"] as? Date
		profileId = plist["UUID"] as? String
		profileName = plist["Name"] as? String
		profileType = parseProfileType(plist, isOSX: isOSX)
		profilePlatform = isOSX ? "Mac" : "iOS"
		teamName = plist["TeamName"] as? String
		teamIds = plist["TeamIdentifier"] as? [String] ?? []
		devices = plist["ProvisionedDevices"] as? [String] ?? []
		certificates = (plist["DeveloperCertificates"] as? [Data] ?? []).compactMap {
			ProvisioningCertificate($0)
		}
		entitlements = plist["Entitlements"] as? PlistDict
	}
}

/// Returns provision type string like "Development" or "Distribution (App Store)".
private func parseProfileType(_ plist: PlistDict, isOSX: Bool) -> String {
	let hasDevices = plist["ProvisionedDevices"] is [Any]
	if isOSX {
		return hasDevices ? "Development" : "Distribution (App Store)"
	}
	if hasDevices {
		let getTaskAllow = (plist["Entitlements"] as? PlistDict)?["get-task-allow"] as? Bool ?? false
		return getTaskAllow ? "Development" : "Distribution (Ad Hoc)"
	}
	let isEnterprise = plist["ProvisionsAllDevices"] as? Bool ?? false
	return isEnterprise ? "Enterprise" : "Distribution (App Store)"
}
