import Foundation
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "PreviewGenerator")

typealias HtmlDict = [String: String] // used for TAG replacements


// MARK: - Generic data formatting & printing

typealias TableRow = [String]

/// Print html table with arbitrary number of columns
/// @param header If set, start the table with a `tr` column row.
func formatAsTable(_ data: [[String]], header: TableRow? = nil) -> String {
	var table = "<table>\n"
	if let header = header {
		table += "<tr><th>\(header.joined(separator: "</th><th>"))</th></tr>\n"
	}
	for row in data {
		table += "<tr><td>\(row.joined(separator: "</td><td>"))</td></tr>\n"
	}
	return table + "</table>\n"
}

/// Print recursive tree of key-value mappings.
func recursiveDict(_ dictionary: [String: Any], withReplacements replacements: [String: String] = [:], _ level: Int = 0) -> String {
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

/// Replace occurrences of chars `&"'<>` with html encoding.
func escapeXML(_ stringToEscape: String) -> String {
	return stringToEscape
		.replacingOccurrences(of: "&", with: "&amp;")
		.replacingOccurrences(of: "\"", with: "&quot;")
		.replacingOccurrences(of: "'", with: "&apos;")
		.replacingOccurrences(of: "<", with: "&lt;")
		.replacingOccurrences(of: ">", with: "&gt;")
}


// MARK: - Date processing

/// @return Difference between two dates as components.
func dateDiff(_ start: Date, _ end: Date) -> DateComponents {
	return Calendar.current.dateComponents([.day, .hour, .minute], from: start, to: end)
}

/// @return Print largest component. E.g., "3 days" or "14 hours"
func relativeDateString(_ comp: DateComponents) -> String {
	let formatter = DateComponentsFormatter()
	formatter.unitsStyle = .full
	formatter.maximumUnitCount = 1
	return formatter.string(from: comp)!
}

/// @return Print the date with current locale and medium length style.
func formattedDate(_ date: Date) -> String {
	let formatter = DateFormatter()
	formatter.dateStyle = .medium
	formatter.timeStyle = .medium
	return formatter.string(from: date)
}

/// Parse date from plist regardless if it has `NSDate` or `NSString` type.
func parseDate(_ value: Any?) -> Date? {
	if let date = value as? Date {
		return date
	}
	
	guard let stringValue = value as? String else {
		return nil
	}
	
	// parse the date from a string
	let formatter = DateFormatter()
	formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
	if let date = formatter.date(from: stringValue) {
		return date
	}
	formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
	if let date = formatter.date(from: stringValue) {
		return date
	}
	os_log(.error, log: log, "ERROR formatting date: %{public}@", stringValue)
	return nil
}

/// @return Relative distance to today. E.g., "Expired today"
func relativeExpirationDateString(_ date: Date) -> String {
	let isPast = date < Date()
	let isToday = Calendar.current.isDateInToday(date)
	
	if isToday {
		return isPast ? "<span>Expired today</span>" : "<span>Expires today</span>"
	}
	
	if isPast {
		let comp = dateDiff(date, Date())
		return "<span>Expired \(relativeDateString(comp)) ago</span>"
	}
	
	let comp = dateDiff(Date(), date)
	if comp.day! < 30 {
		return "<span>Expires in \(relativeDateString(comp))</span>"
	}
	return "Expires in \(relativeDateString(comp))"
}

/// @return Relative distance to today. E.g., "DATE (Expires in 3 days)"
func formattedExpirationDate(_ date: Date) -> String {
	return "\(formattedDate(date)) (\(relativeExpirationDateString(date)))"
}

/// @return Relative distance to today. E.g., "DATE (Created 3 days ago)"
func formattedCreationDate(_ date: Date) -> String {
	let isToday = Calendar.current.isDateInToday(date)
	let comp = dateDiff(date, Date())
	return "\(formattedDate(date)) (Created \(isToday ? "today" : "\(relativeDateString(comp)) ago"))"
}

/// @return CSS class for expiration status.
func classNameForExpirationStatus(_ date: Date?) -> String {
	switch ExpirationStatus(date) {
	case .Expired:  return "expired"
	case .Expiring: return "expiring"
	case .Valid:    return "valid"
	}
}


// MARK: - App Info

/// @return List of ATS flags.
func formattedAppTransportSecurity(_ appPlist: PlistDict) -> String {
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
func procAppInfo(_ appPlist: PlistDict?) -> HtmlDict {
	guard let appPlist else {
		return [
			"AppInfoHidden": "hiddenDiv",
			"ProvisionTitleHidden": "",
		]
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
	return [
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
	]
}


// MARK: - iTunes Purchase Information

/// Concatenate all (sub)genres into a comma separated list.
func formattedGenres(_ itunesPlist: PlistDict) -> String {
	var genres: [String] = []
	let genreId = itunesPlist["genreId"] as? Int ?? 0
	if let mainGenre = AppCategories[genreId] ?? itunesPlist["genre"] as? String {
		genres.append(mainGenre)
	}
	
	for subgenre in itunesPlist["subgenres"] as? [PlistDict] ?? [] {
		let subgenreId = subgenre["genreId"] as? Int ?? 0
		if let subgenreStr = AppCategories[subgenreId] ?? subgenre["genre"] as? String {
			genres.append(subgenreStr)
		}
	}
	return genres.joined(separator: ", ")
}

/// Process info stored in `iTunesMetadata.plist`
func parseItunesMeta(_ itunesPlist: PlistDict?) -> HtmlDict {
	guard let itunesPlist else {
		return ["iTunesHidden": "hiddenDiv"]
	}
	
	let downloadInfo = itunesPlist["com.apple.iTunesStore.downloadInfo"] as? PlistDict
	let accountInfo = downloadInfo?["accountInfo"] as? PlistDict ?? [:]
	
	let purchaseDate = parseDate(downloadInfo?["purchaseDate"] ?? itunesPlist["purchaseDate"])
	let releaseDate = parseDate(downloadInfo?["releaseDate"] ?? itunesPlist["releaseDate"])
	// AppleId & purchaser name
	let appleId = accountInfo["AppleID"] as? String ?? itunesPlist["appleId"] as? String ?? ""
	let firstName = accountInfo["FirstName"] as? String ?? ""
	let lastName = accountInfo["LastName"] as? String ?? ""
	
	let name: String
	if !firstName.isEmpty || !lastName.isEmpty {
		name = "\(firstName) \(lastName) (\(appleId))"
	} else {
		name = appleId
	}
	os_log(.error, log: log, "id: %{public}@", String(describing: itunesPlist["itemId"]))
	return [
		"iTunesHidden": "",
		"iTunesId": (itunesPlist["itemId"] as? Int)?.description ?? "", // description]
		"iTunesName": itunesPlist["itemName"] as? String ?? "",
		"iTunesGenres": formattedGenres(itunesPlist),
		"iTunesReleaseDate": releaseDate == nil ? "" : formattedDate(releaseDate!),

		"iTunesAppleId": name,
		"iTunesPurchaseDate": purchaseDate == nil ? "" : formattedDate(purchaseDate!),
		"iTunesPrice": itunesPlist["priceDisplay"] as? String ?? "",
	]
}


// MARK: - Certificates

/// Process a single certificate. Extract invalidity / expiration date.
/// @param subject just used for printing error logs.
func getCertificateInvalidityDate(_ certificate: SecCertificate, subject: String) -> Date? {
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
	return parseDate(dateString);
}

/// Process list of all certificates. Return a two column table with subject and expiration date.
func getCertificateList(_ provisionPlist: PlistDict) -> [TableRow] {
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
			expiration = relativeExpirationDateString(invalidityDate)
		} else {
			expiration = "<span class='warning'>No invalidity date in certificate</span>"
		}
		return TableRow([subject, expiration])
	}.sorted { $0[0] < $1[0] }
}


// MARK: - Provisioning

/// Returns provision type string like "Development" or "Distribution (App Store)".
func stringForProfileType(_ provisionPlist: PlistDict, isOSX: Bool) -> String {
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
func getDeviceList(_ provisionPlist: PlistDict) -> [TableRow] {
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
func procProvision(_ provisionPlist: PlistDict?, isOSX: Bool) -> HtmlDict {
	guard let provisionPlist else {
		return ["ProvisionHidden": "hiddenDiv"]
	}

	let creationDate = provisionPlist["CreationDate"] as? Date
	let expireDate = provisionPlist["ExpirationDate"] as? Date
	let devices = getDeviceList(provisionPlist)
	let certs = getCertificateList(provisionPlist)
	
	return [
		"ProvisionHidden": "",
		"ProfileName": provisionPlist["Name"] as? String ?? "",
		"ProfileUUID": provisionPlist["UUID"] as? String ?? "",
		"TeamName": provisionPlist["TeamName"] as? String ?? "<em>Team name not available</em>",
		"TeamIds": (provisionPlist["TeamIdentifier"] as? [String])?.joined(separator: ", ") ?? "<em>Team ID not available</em>",
		"CreationDateFormatted": creationDate == nil ? "" : formattedCreationDate(creationDate!),
		"ExpirationDateFormatted": expireDate == nil ? "" : formattedExpirationDate(expireDate!),
		"ExpStatus": classNameForExpirationStatus(expireDate),

		"ProfilePlatform": isOSX ? "Mac" : "iOS",
		"ProfileType": stringForProfileType(provisionPlist, isOSX: isOSX),

		"ProvisionedDevicesCount": devices.isEmpty ? "No Devices" : "\(devices.count) Device\(devices.count == 1 ? "" : "s")",
		"ProvisionedDevicesFormatted": devices.isEmpty ? "Distribution Profile" : formatAsTable(devices, header: ["", "UDID"]),

		"DeveloperCertificatesFormatted": certs.isEmpty ? "No Developer Certificates" : formatAsTable(certs),
	]
}


// MARK: - Entitlements

/// Search for app binary and run `codesign` on it.
func readEntitlements(_ meta: QuickLookInfo, _ bundleExecutable: String?) -> Entitlements {
	guard let bundleExecutable else {
		return Entitlements.withoutBinary()
	}
	
	switch meta.type {
	case .IPA:
		let tmpPath = NSTemporaryDirectory() + "/" + UUID().uuidString
		try! FileManager.default.createDirectory(atPath: tmpPath, withIntermediateDirectories: true)
		defer {
			try? FileManager.default.removeItem(atPath: tmpPath)
		}
		try! meta.zipFile!.unzipFile("Payload/*.app/\(bundleExecutable)", toDir: tmpPath)
		return Entitlements(forBinary: tmpPath + "/" + bundleExecutable)
	case .Archive:
		return Entitlements(forBinary: meta.effectiveUrl!.path + "/" + bundleExecutable)
	case .Extension:
		return Entitlements(forBinary: meta.url.path + "/" + bundleExecutable)
	}
}

/// Process compiled binary and provision plist to extract `Entitlements`
func procEntitlements(_ meta: QuickLookInfo, _ appPlist: PlistDict?, _ provisionPlist: PlistDict?) -> HtmlDict {
	var entitlements = readEntitlements(meta, appPlist?["CFBundleExecutable"] as? String)
	entitlements.applyFallbackIfNeeded(provisionPlist?["Entitlements"] as? PlistDict)
	
	return [
		"EntitlementsWarningHidden": entitlements.hasError ? "" : "hiddenDiv",
		"EntitlementsFormatted": entitlements.html ?? "No Entitlements",
	]
}


// MARK: - File Info

/// Title of the preview window
func stringForFileType(_ meta: QuickLookInfo) -> String {
	switch meta.type {
	case .IPA:       return "App info"
	case .Archive:   return "Archive info"
	case .Extension: return "App extension info"
	}
}

/// Calculate file / folder size.
func getFileSize(_ path: String) -> Int64 {
	var isDir: ObjCBool = false
	FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
	if !isDir.boolValue {
		return try! FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64
	}
	var fileSize: Int64 = 0
	for child in try! FileManager.default.subpathsOfDirectory(atPath: path) {
		fileSize += try! FileManager.default.attributesOfItem(atPath: path + "/" + child)[.size] as! Int64
	}
	return fileSize
}

/// Process meta information about the file itself. Like file size and last modification.
func procFileInfo(_ url: URL) -> HtmlDict {
	let formattedValue : String
	if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
		let size = ByteCountFormatter.string(fromByteCount: getFileSize(url.path), countStyle: .file)
		formattedValue = "\(size), Modified \(formattedDate(attrs[.modificationDate] as! Date))"
	} else {
		formattedValue = ""
	}
	return [
		"FileName": escapeXML(url.lastPathComponent),
		"FileInfo": formattedValue,
	]
}


// MARK: - Footer Info

/// Process meta information about the plugin. Like version and debug flag.
func procFooterInfo() -> HtmlDict {
#if DEBUG
	let debugString = "(debug)"
#else
	let debugString = ""
#endif
	return [
		"DEBUG": debugString,
		"BundleShortVersionString": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
		"BundleVersion": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
	]
}


// MARK: - Main Entry

func applyHtmlTemplate(_ templateValues: HtmlDict) -> String {
	let templateURL = Bundle.main.url(forResource: "template", withExtension: "html")!
	let html = try! String(contentsOf: templateURL, encoding: .utf8)
	
	// this is less efficient
//	for (key, value) in templateValues {
//		html = html.replacingOccurrences(of: "__\(key)__", with: value)
//	}
	
	var rv = ""
	var prevLoc = html.startIndex
	let regex = try! NSRegularExpression(pattern: "__[^ _]{1,40}?__")
	regex.enumerateMatches(in: html, range: NSRange(location: 0, length: html.count), using: { match, flags, stop  in
		let start = html.index(html.startIndex, offsetBy: match!.range.lowerBound)
		let key = String(html[html.index(start, offsetBy: 2) ..< html.index(start, offsetBy: match!.range.length - 2)])
		// append unrelated text up to this key
		rv.append(contentsOf: html[prevLoc ..< start])
		prevLoc = html.index(start, offsetBy: match!.range.length)
		// append key if exists (else remove template-key)
		if let value = templateValues[key] {
			rv.append(value)
		} else {
//			os_log(.debug, log: log, "unknown template key: %{public}@", key)
		}
	})
	// append remaining text
	rv.append(contentsOf: html[prevLoc ..< html.endIndex])
	return rv
}

func generateHtml(at url: URL) -> String {
	let meta = QuickLookInfo(url)
	var infoLayer: HtmlDict = [
		"AppInfoTitle": stringForFileType(meta),
	]
	
	// App Info
	let plistApp = meta.readPlistApp()
	infoLayer.merge(procAppInfo(plistApp)) { (_, new) in new }
	
	let plistItunes = meta.readPlistItunes()
	infoLayer.merge(parseItunesMeta(plistItunes)) { (_, new) in new }
	
	// Provisioning
	let plistProvision = meta.readPlistProvision()
	infoLayer.merge(procProvision(plistProvision, isOSX: meta.isOSX)) { (_, new) in new }
	
	// Entitlements
	let entitlements = procEntitlements(meta, plistApp, plistProvision)
	infoLayer.merge(entitlements) { (_, new) in new }
	// File Info
	infoLayer.merge(procFileInfo(url)) { (_, new) in new }
	// Footer Info
	infoLayer.merge(procFooterInfo()) { (_, new) in new }
	// App Icon (last, because the image uses a lot of memory)
	let icon = AppIcon(meta)
	infoLayer["AppIcon"] = icon.extractImage(from: plistApp).withRoundCorners().asBase64()
	// prepare html, replace values
	return applyHtmlTemplate(infoLayer)
}
