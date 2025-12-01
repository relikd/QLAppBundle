import Foundation
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Html+Date")

extension DateComponents {
	/// @return Print largest component. E.g., "3 days" or "14 hours"
	fileprivate func relativeDateString() -> String {
		let formatter = DateComponentsFormatter()
		formatter.unitsStyle = .full
		formatter.maximumUnitCount = 1
		return formatter.string(from: self)!
	}
}

extension Date {
	/// @return Print the date with current locale and medium length style.
	func mediumFormat() -> String {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .medium
		return formatter.string(from: self)
	}
	
	/// Parse date from plist regardless if it has `NSDate` or `NSString` type.
	static func parseAny(_ value: Any?) -> Date? {
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
	
	/// @return Difference between two dates as components.
	private func diff(_ other: Date) -> DateComponents {
		return Calendar.current.dateComponents([.day, .hour, .minute], from: self, to: other)
	}
	
	/// @return Relative distance to today. E.g., "Expired today"
	func relativeExpirationDateString() -> String {
		let isPast = self < Date()
		let isToday = Calendar.current.isDateInToday(self)
		
		if isToday {
			return isPast ? "<span>Expired today</span>" : "<span>Expires today</span>"
		}
		
		if isPast {
			let comp = self.diff(Date())
			return "<span>Expired \(comp.relativeDateString()) ago</span>"
		}
		
		let comp = Date().diff(self)
		if comp.day! < 30 {
			return "<span>Expires in \(comp.relativeDateString())</span>"
		}
		return "Expires in \(comp.relativeDateString())"
	}

	/// @return Relative distance to today. E.g., "DATE (Expires in 3 days)"
	func formattedExpirationDate() -> String {
		return "\(self.mediumFormat()) (\(relativeExpirationDateString()))"
	}

	/// @return Relative distance to today. E.g., "DATE (Created 3 days ago)"
	func formattedCreationDate() -> String {
		let isToday = Calendar.current.isDateInToday(self)
		let comp = self.diff(Date())
		return "\(self.mediumFormat()) (Created \(isToday ? "today" : "\(comp.relativeDateString()) ago"))"
	}
}
