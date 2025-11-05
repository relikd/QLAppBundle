import Foundation

extension MetaInfo {	
	/// Read `iTunesMetadata.plist` if available
	func readPlistItunes() -> PlistDict? {
		switch self.type {
		case .IPA:
			// not `readPayloadFile` because plist is in root dir
			return self.zipFile!.unzipFile("iTunesMetadata.plist")?.asPlistOrNil()
		case .Archive, .Extension:
			return nil
		}
	}
}


extension PreviewGenerator {
	/// Concatenate all (sub)genres into a comma separated list.
	private func formattedGenres(_ itunesPlist: PlistDict) -> String {
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
	mutating func procItunesMeta(_ itunesPlist: PlistDict?) {
		guard let itunesPlist else {
			self.apply(["iTunesHidden": CLASS_HIDDEN])
			return
		}
		
		let downloadInfo = itunesPlist["com.apple.iTunesStore.downloadInfo"] as? PlistDict
		let accountInfo = downloadInfo?["accountInfo"] as? PlistDict ?? [:]
		
		let purchaseDate = Date.parseAny(downloadInfo?["purchaseDate"] ?? itunesPlist["purchaseDate"])
		let releaseDate = Date.parseAny(downloadInfo?["releaseDate"] ?? itunesPlist["releaseDate"])
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
		self.apply([
			"iTunesHidden": CLASS_VISIBLE,
			"iTunesId": (itunesPlist["itemId"] as? Int)?.description ?? "",
			"iTunesName": itunesPlist["itemName"] as? String ?? "",
			"iTunesGenres": formattedGenres(itunesPlist),
			"iTunesReleaseDate": releaseDate?.mediumFormat() ?? "",
			
			"iTunesAppleId": name,
			"iTunesPurchaseDate": purchaseDate?.mediumFormat() ?? "",
			"iTunesPrice": itunesPlist["priceDisplay"] as? String ?? "",
		])
	}
}
