import Foundation

extension PreviewGenerator {
	/// Process info stored in `iTunesMetadata.plist`
	mutating func procItunesMeta(_ itunesPlist: Plist_iTunesMetadata?) {
		guard let itunesPlist else {
			return
		}
		self.apply([
			"iTunesHidden": CLASS_VISIBLE,
			"iTunesId": itunesPlist.appId?.description ?? "",
			"iTunesName": itunesPlist.appName ?? "",
			"iTunesGenres": itunesPlist.genres.joined(separator: ", "),
			"iTunesReleaseDate": itunesPlist.releaseDate?.mediumFormat() ?? "",
			
			"iTunesAppleId": itunesPlist.purchaserName ?? "",
			"iTunesPurchaseDate": itunesPlist.purchaseDate?.mediumFormat() ?? "",
			"iTunesPrice": itunesPlist.price ?? "",
		])
	}
}
