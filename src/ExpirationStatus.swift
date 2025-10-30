import Foundation

enum ExpirationStatus {
	case Expired
	case Expiring
	case Valid
	
	/// Check time between date and now. Set Expiring if less than 30 days until expiration
	init(_ date: Date?) {
		if date == nil || date!.timeIntervalSinceNow < 0 {
			self = .Expired
		}
		let components = Calendar.current.dateComponents([.day], from: Date(), to: date!)
		self = components.day! < 30 ? .Expiring : .Valid
	}
	
	/// @return CSS class for expiration status.
	func cssClass() -> String {
		switch self {
		case .Expired:  return "expired"
		case .Expiring: return "expiring"
		case .Valid:    return "valid"
		}
	}
}
