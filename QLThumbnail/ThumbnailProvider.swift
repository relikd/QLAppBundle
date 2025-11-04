import QuickLookThumbnailing
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "thumbnail-plugin")

extension QLThumbnailReply {
	/// call private method `setIconFlavor:`
	/// see https://medium.com/swlh/calling-ios-and-macos-hidden-api-in-style-1a924f244ad1
	fileprivate func setFlavor(_ flavor: Int) {
		typealias setIconFlavorMethod = @convention(c) (NSObject, Selector, NSInteger) -> Bool
		let selector = NSSelectorFromString("setIconFlavor:")
		let imp = self.method(for: selector)
		let method = unsafeBitCast(imp, to: setIconFlavorMethod.self)
		_ = method(self, selector, flavor)
	}
}

class ThumbnailProvider: QLThumbnailProvider {
	
	// TODO: sadly, this does not seem to work for .xcarchive and .appex
	// Probably overwritten by Apple somehow
	
	override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
		let meta = MetaInfo(request.fileURL)
		guard let appPlist = meta.readPlistApp() else {
			return
		}
		let img = AppIcon(meta).extractImage(from: appPlist).withRoundCorners()
		
		// First way: Draw the thumbnail into the current context, set up with UIKit's coordinate system.
		let reply = QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
			img.draw(in: CGRect(origin: .zero, size: request.maximumSize))
			return true
		})
		// defer in case `setFlavor` fails
		defer {
			handler(reply, nil)
		}
		// 0: Plain transparent, 1: Shadow, 2: Book, 3: Movie, 4: Address, 5: Image,
		// 6: Gloss, 7: Slide, 8: Square, 9: Border, 11: Calendar, 12: Pattern
		reply.setFlavor(meta.type == .Archive ? 12 : 0) // .archive looks like "in development"
	}
}

