import cbedrock
import RAW

/// returns a ``time_t`` struct representing the reference date for this Date type.
/// **NOTE**: the reference date is 00:00:00 UTC on 1 January 2001.
fileprivate func systemReferenceDate() -> time_t {
	var timeStruct = tm()
	memset(&timeStruct, 0, MemoryLayout<tm>.size)
	timeStruct.tm_mday = 1
	timeStruct.tm_mon = 0
	timeStruct.tm_year = 101
	return mktime(&timeStruct)
}
internal let refDate = systemReferenceDate()

/// returns a ``time_t`` struct representing the reference date for this Date type.
/// **NOTE**: the reference date is 00:00:00 UTC on 1 January 1970.
fileprivate func encodingReferenceDate() -> time_t {
	var timeStruct = tm()
	memset(&timeStruct, 0, MemoryLayout<tm>.size)
	timeStruct.tm_mday = 1
	timeStruct.tm_mon = 0
	timeStruct.tm_year = 70
	return mktime(&timeStruct)
}
internal let encDate = encodingReferenceDate()


/// a structure that represents a single point of time.
/// - this structure provides no detail around timezones the date is represented in.
@RAW_staticbuff(bytes:4)
@RAW_staticbuff_binaryfloatingpoint_type<Double>()
@frozen public struct Date:Sendable {
	/// initialize a new date based on the GMT timezone.
	public init() {
		self = Self(localTime:false)
	}

	/// initialize a new date based on either the local timezone or the GMT timezone.
	public init(localTime:Bool) {

		// capture the current time.
		var ts = timespec()
		clock_gettime(CLOCK_REALTIME, &ts)
		let seconds = Double(ts.tv_sec)
		let nanoseconds = Double(ts.tv_nsec)
		let total_time = seconds + (nanoseconds / 1_000_000_000)
		
		switch localTime {
			case false:
				// capture the local time and account for the timezone adjustments
				var Cnow = time_t()
				let loc = localtime(&Cnow).pointee
				var offset = Double(loc.tm_gmtoff)
				
				// correct for daylight savings time if it is in effect
				if loc.tm_isdst > 0 {
					offset += 3600
				}
				
				self.init(RAW_native:(total_time + offset))
			case true:
				self.init(RAW_native:total_time)
		}
	}

	/// initialize with a Unix epoch interval (seconds since 00:00:00 UTC on 1 January 1970)
	public init(unixInterval:Double) {
		self.init(RAW_native:unixInterval)
	}

	/// basic initializer based on the primitive (seconds since 00:00:00 UTC on 1 January 1970)
	public init(referenceInterval:Double) {
		self.init(RAW_native:(referenceInterval + 978307200))
	}

	/// returns the difference in time between the called instance and passed date
	public func timeIntervalSince(_ other:Self) -> Double {
		return self.RAW_native() - other.RAW_native()
	}

	/// returns a new value that is the sum of the current value and the passed interval
	public func addingTimeInterval(_ interval:Double) -> Self {
		return Self(referenceInterval:self.RAW_native() + interval)
	}

	/// returns the time interval since Unix date
	public func timeIntervalSinceUnixDate() -> Double {
		return self.RAW_native()
	}

	/// returns the time interval since the reference date (00:00:00 UTC on 1 January 2001)
	public func timeIntervalSinceReferenceDate() -> Double {
		return self.RAW_native() - 978307200
	}
}

extension Date:Comparable {
	public static func < (lhs:Date, rhs:Date) -> Bool {
		return lhs.RAW_native() < rhs.RAW_native()
	}
	public static func == (lhs:Date, rhs:Date) -> Bool {
		return lhs.RAW_native() == rhs.RAW_native()
	}
}