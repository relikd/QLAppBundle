import Foundation

extension MetaInfo {
	/// Read `iTunesMetadata.plist` (if available)
	func readPlist_iTunesMetadata() -> Plist_iTunesMetadata? {
		assert(type == .IPA)
		// not `readPayloadFile` because plist is in root dir
		guard let plist = self.zipFile!.unzipFile("iTunesMetadata.plist")?.asPlistOrNil() else {
			return nil
		}
		return Plist_iTunesMetadata(plist)
	}
}


// MARK: - Plist_iTunesMetadata

/// Representation of `iTunesMetadata.plist`
struct Plist_iTunesMetadata {
	let appId: Int?
	let appName: String?
	let price: String?
	let genres: [String]
	// purchase info
	let releaseDate: Date?
	let purchaseDate: Date?
	// account info
	let appleId: String?
	let firstName: String?
	let lastName: String?
	
	init(_ plist: PlistDict) {
		appId = plist["itemId"] as? Int
		appName = plist["itemName"] as? String
		price = plist["priceDisplay"] as? String
		genres = formattedGenres(plist)
		// download info
		let downloadInfo = plist["com.apple.iTunesStore.downloadInfo"] as? PlistDict
		purchaseDate = Date.parseAny(downloadInfo?["purchaseDate"] ?? plist["purchaseDate"])
		releaseDate = Date.parseAny(downloadInfo?["releaseDate"] ?? plist["releaseDate"])
		// AppleId & purchaser name
		let accountInfo = downloadInfo?["accountInfo"] as? PlistDict ?? [:]
		appleId = accountInfo["AppleID"] as? String ?? plist["appleId"] as? String
		firstName = accountInfo["FirstName"] as? String
		lastName = accountInfo["LastName"] as? String
	}
	
	/// Returns `"<firstName> <lastName> (<appleId>)"` (with empty values omitted)
	var purchaserName: String? {
		let fn = firstName ?? ""
		let ln = lastName ?? ""
		let aid = appleId ?? ""
		switch (fn.isEmpty, ln.isEmpty, aid.isEmpty) {
		case (true, true, true): return nil
		case (true, true, false): return "\(aid)"
		case (_, _, false): return "\(fn) \(ln) (\(aid))"
		case (_, _, true): return "\(fn) \(ln)"
		}
	}
}

/// Concatenate all (sub)genres into flat list.
private func formattedGenres(_ plist: PlistDict) -> [String] {
	var genres: [String] = []
	let genreId = plist["genreId"] as? Int ?? 0
	if let mainGenre = AppCategories[genreId] ?? plist["genre"] as? String {
		genres.append(mainGenre)
	}
	
	for subgenre in plist["subgenres"] as? [PlistDict] ?? [] {
		let subgenreId = subgenre["genreId"] as? Int ?? 0
		if let subgenreStr = AppCategories[subgenreId] ?? subgenre["genre"] as? String {
			genres.append(subgenreStr)
		}
	}
	return genres
}
