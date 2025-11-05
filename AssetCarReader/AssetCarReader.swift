import Foundation
import AppKit // NSImage
private import CoreUI // CUICatalog
private import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AssetCarReader")

public class CarReader {
	private let catalog: CUICatalog
	
	public init?(_ data: Data) {
		do {
			catalog = try data.withUnsafeBytes { try CUICatalog(bytes: $0.baseAddress!, length: UInt64(data.count)) }
		} catch {
			os_log(.error, log: log, "[asset-car] ERROR: could not open catalog: %{public}@", error.localizedDescription)
			return nil
		}
	}
	
	/// Use `CUICatalog` to extract an image from `Assets.car`
	public func imageFromAssetsCar(_ imageName: String) -> NSImage? {
		if let validName = verifyNameExists(imageName, in: catalog) {
			if let bestImage = findHighestResolutionIcon(catalog.images(withName: validName)) {
				os_log(.debug, log: log, "[asset-car] using Assets.car with key %{public}@", validName)
				return NSImage(cgImage: bestImage.image, size: bestImage.size)
			}
		}
		return nil
	}
	
	
	// MARK: - Private methods
	
	/// Helper method to check available icon names. Will return a valid name or `nil` if no image with that key is found.
	private func verifyNameExists(_ imageName: String, in catalog: CUICatalog) -> String? {
		if let availableNames = catalog.allImageNames(), !availableNames.contains(imageName) {
			// Theoretically this should never happen. Assuming the image name is found in an image file.
			os_log(.info, log: log, "[asset-car] WARN: key '%{public}@' does not match any available key", imageName)
			
			if let alternativeName = searchAlternativeName(imageName, inAvailable: availableNames) {
				os_log(.info, log: log, "[asset-car] falling back to '%{public}@'", alternativeName)
				return alternativeName
			}
			os_log(.debug, log: log, "[asset-car] available keys: %{public}@", catalog.allImageNames() ?? [])
			return nil
		}
		return imageName
	}
	
	/// If exact name does not exist in catalog, search for a name that shares the same prefix.
	/// E.g., "AppIcon60x60" may match "AppIcon" or "AppIcon60x60_small"
	private func searchAlternativeName(_ originalName: String, inAvailable availableNames: [String]) -> String? {
		var bestOption: String? = nil
		var bestDiff: Int = 999
		
		for option in availableNames {
			if option.hasPrefix(originalName) || originalName.hasPrefix(option) {
				let thisDiff = max(originalName.count, option.count) - min(originalName.count, option.count)
				if thisDiff < bestDiff {
					bestDiff = thisDiff
					bestOption = option
				}
			}
		}
		return bestOption
	}
	
	/// Given a list of `CUINamedImage`, return the one with the highest resolution. Vector graphics are ignored.
	private func findHighestResolutionIcon(_ availableImages: [CUINamedImage]) -> CUINamedImage? {
		var largestWidth: CGFloat = 0
		var largestImage: CUINamedImage? = nil
		// cast to NSArray is necessary as otherwise this will crash
		for img in availableImages as NSArray {
			guard let img = img as? CUINamedImage else {
				continue // ignore CUINamedMultisizeImageSet
			}
			let w = img.size.width
			if w > largestWidth {
				largestWidth = w
				largestImage = img
			}
		}
		return largestImage
	}
}
