import Foundation
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Html+Certificates")


extension MetaInfo {
	/// Read `embedded.mobileprovision` file and decode with CMS decoder.
	func readPlistProvision() -> PlistDict? {
		guard let provisionData = self.readPayloadFile("embedded.mobileprovision", osxSubdir: nil) else {
			os_log(.info, log: log, "No embedded.mobileprovision file for %{public}@", self.url.path)
			return nil
		}
		
		var decoder: CMSDecoder? = nil
		CMSDecoderCreate(&decoder)
		let data = provisionData.withUnsafeBytes { ptr in
			CMSDecoderUpdateMessage(decoder!, ptr.baseAddress!, provisionData.count)
			CMSDecoderFinalizeMessage(decoder!)
			var dataRef: CFData?
			CMSDecoderCopyContent(decoder!, &dataRef)
			return Data(referencing: dataRef!)
		}
		return data.asPlistOrNil()
	}
}


extension PreviewGenerator {
	
	// MARK: - Certificates
	
	/// Process a single certificate. Extract invalidity / expiration date.
	/// @param subject just used for printing error logs.
	private func getCertificateInvalidityDate(_ certificate: SecCertificate, subject: String) -> Date? {
		var error: Unmanaged<CFError>?
		guard let outerDict = SecCertificateCopyValues(certificate, [kSecOIDInvalidityDate] as CFArray, &error) as? PlistDict else {
			os_log(.error, log: log, "Could not get values in '%{public}@' certificate, error = %{public}@", subject, error?.takeUnretainedValue().localizedDescription ?? "unknown error")
			return nil
		}
		guard let innerDict = outerDict[kSecOIDInvalidityDate as String] as? PlistDict else {
			os_log(.error, log: log, "No invalidity values in '%{public}@' certificate, dictionary = %{public}@", subject, outerDict)
			return nil
		}
		// NOTE: the invalidity date type of kSecPropertyTypeDate is documented as a CFStringRef in the "Certificate, Key, and Trust Services Reference".
		// In reality, it's a __NSTaggedDate (presumably a tagged pointer representing an NSDate.) But to be sure, we'll check:
		guard let dateString = innerDict[kSecPropertyKeyValue as String] else {
			os_log(.error, log: log, "No invalidity date in '%{public}@' certificate, dictionary = %{public}@", subject, innerDict)
			return nil
		}
		return Date.parseAny(dateString)
	}
	
	/// Process list of all certificates. Return a two column table with subject and expiration date.
	private func getCertificateList(_ provisionPlist: PlistDict) -> [TableRow] {
		guard let certs = provisionPlist["DeveloperCertificates"] as? [Data] else {
			return []
		}
		return certs.compactMap {
			guard let cert = SecCertificateCreateWithData(nil, $0 as CFData) else {
				return nil
			}
			guard let subject = SecCertificateCopySubjectSummary(cert) as? String else {
				os_log(.error, log: log, "Could not get subject from certificate")
				return nil
			}
			let expiration: String
			if let invalidityDate = getCertificateInvalidityDate(cert, subject: subject) {
				expiration = invalidityDate.relativeExpirationDateString()
			} else {
				expiration = "<span class='warning'>No invalidity date in certificate</span>"
			}
			return TableRow([subject, expiration])
		}.sorted { $0[0] < $1[0] }
	}
	
	
	// MARK: - Provisioning

	/// Returns provision type string like "Development" or "Distribution (App Store)".
	private func stringForProfileType(_ provisionPlist: PlistDict, isOSX: Bool) -> String {
		let hasDevices = provisionPlist["ProvisionedDevices"] is [Any]
		if isOSX {
			return hasDevices ? "Development" : "Distribution (App Store)"
		}
		if hasDevices {
			let getTaskAllow = (provisionPlist["Entitlements"] as? PlistDict)?["get-task-allow"] as? Bool ?? false
			return getTaskAllow ? "Development" : "Distribution (Ad Hoc)"
		}
		let isEnterprise = provisionPlist["ProvisionsAllDevices"] as? Bool ?? false
		return isEnterprise ? "Enterprise" : "Distribution (App Store)"
	}
	
	/// Enumerate all entries from provison plist with key `ProvisionedDevices`
	private func getDeviceList(_ provisionPlist: PlistDict) -> [TableRow] {
		guard let devArr = provisionPlist["ProvisionedDevices"] as? [String] else {
			return []
		}
		var currentPrefix: String? = nil
		return devArr.sorted().map { device in
			// compute the prefix for the first column of the table
			let displayPrefix: String
			let devicePrefix = String(device.prefix(1))
			if currentPrefix != devicePrefix {
				currentPrefix = devicePrefix
				displayPrefix = "\(devicePrefix) ➞ "
			} else {
				displayPrefix = ""
			}
			return [displayPrefix, device]
		}
	}
	
	/// Process info stored in `embedded.mobileprovision`
	mutating func procProvision(_ provisionPlist: PlistDict?, isOSX: Bool) {
		guard let provisionPlist else {
			return
		}
		
		let creationDate = provisionPlist["CreationDate"] as? Date
		let expireDate = provisionPlist["ExpirationDate"] as? Date
		let devices = getDeviceList(provisionPlist)
		let certs = getCertificateList(provisionPlist)
		
		self.apply([
			"ProvisionHidden": CLASS_VISIBLE,
			"ProvisionProfileName": provisionPlist["Name"] as? String ?? "",
			"ProvisionProfileId": provisionPlist["UUID"] as? String ?? "",
			"ProvisionTeamName": provisionPlist["TeamName"] as? String ?? "<em>Team name not available</em>",
			"ProvisionTeamIds": (provisionPlist["TeamIdentifier"] as? [String])?.joined(separator: ", ") ?? "<em>Team ID not available</em>",
			"ProvisionCreateDate": creationDate?.formattedCreationDate() ?? "",
			"ProvisionExpireDate": expireDate?.formattedExpirationDate() ?? "",
			"ProvisionExpireStatus": ExpirationStatus(expireDate).cssClass(),
			
			"ProvisionProfilePlatform": isOSX ? "Mac" : "iOS",
			"ProvisionProfileType": stringForProfileType(provisionPlist, isOSX: isOSX),
			
			"ProvisionDeviceCount": devices.isEmpty ? "No Devices" : "\(devices.count) Device\(devices.count == 1 ? "" : "s")",
			"ProvisionDeviceIds": devices.isEmpty ? "Distribution Profile" : formatAsTable(devices, header: ["", "UDID"]),
			
			"ProvisionDevelopCertificates": certs.isEmpty ? "No Developer Certificates" : formatAsTable(certs),
		])
	}
}

private typealias TableRow = [String]

/// Print html table with arbitrary number of columns
/// @param header If set, start the table with a `tr` column row.
private func formatAsTable(_ data: [[String]], header: TableRow? = nil) -> String {
	var table = "<table>\n"
	if let header = header {
		table += "<tr><th>\(header.joined(separator: "</th><th>"))</th></tr>\n"
	}
	for row in data {
		table += "<tr><td>\(row.joined(separator: "</td><td>"))</td></tr>\n"
	}
	return table + "</table>\n"
}
