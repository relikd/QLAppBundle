import Foundation

extension PreviewGenerator {
	/// Process info stored in `embedded.mobileprovision`
	mutating func procProvision(_ provisionPlist: Plist_MobileProvision?) {
		guard let provisionPlist else {
			return
		}
		
		let deviceCount = provisionPlist.devices.count
		self.apply([
			"ProvisionHidden": CLASS_VISIBLE,
			"ProvisionProfileName": provisionPlist.profileName ?? "",
			"ProvisionProfileId": provisionPlist.profileId ?? "",
			"ProvisionTeamName": provisionPlist.teamName ?? "<em>Team name not available</em>",
			"ProvisionTeamIds": provisionPlist.teamIds.isEmpty ? "<em>Team ID not available</em>" : provisionPlist.teamIds.joined(separator: ", "),
			"ProvisionCreateDate": provisionPlist.creationDate?.formattedCreationDate() ?? "",
			"ProvisionExpireDate": provisionPlist.expireDate?.formattedExpirationDate() ?? "",
			"ProvisionExpireStatus": ExpirationStatus(provisionPlist.expireDate).cssClass(),
			
			"ProvisionProfilePlatform": provisionPlist.profilePlatform,
			"ProvisionProfileType": provisionPlist.profileType,
			
			"ProvisionDeviceCount": deviceCount == 0 ? "No Devices" : "\(deviceCount) Device\(deviceCount == 1 ? "" : "s")",
			"ProvisionDeviceIds": deviceCount == 0 ? "Distribution Profile" : formatAsTable(groupDevices(provisionPlist.devices), header: ["", "UDID"]),
			
			"ProvisionDevelopCertificates": provisionPlist.certificates.isEmpty ? "No Developer Certificates"
			: formatAsTable(
				provisionPlist.certificates
					.sorted { $0.subject < $1.subject }
					.map {TableRow([$0.subject, $0.expiration?.relativeExpirationDateString() ?? "<span class='warning'>No invalidity date in certificate</span>"])}
			),
		])
	}
}

/// Group device ids by first letter (`d -> device02`)
private func groupDevices(_ devices: [String]) -> [TableRow] {
	var currentPrefix: String? = nil
	return devices.sorted().map { device in
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
