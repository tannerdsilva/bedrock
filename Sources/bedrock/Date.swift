import RAW

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

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
@RAW_staticbuff(bytes:8)
@RAW_staticbuff_binaryfloatingpoint_type<Double>()
@frozen public struct Date:Sendable {

	@RAW_staticbuff(bytes:8)
	@RAW_staticbuff_fixedwidthinteger_type<UInt64>(bigEndian:true)
	@frozen public struct Seconds:Sendable {
		public init() {
			self.init(RAW_native:UInt64(Date().RAW_native()))
		}
		public init(localTime:Bool) {
			self.init(RAW_native:UInt64(Date(localTime:localTime).RAW_native()))
		}
		/// returns the difference in time between the called instance and passed date
		public func timeIntervalSince(_ other:Self) -> UInt64 {
			return self.RAW_native() - other.RAW_native()
		}
		/// returns a new value that is the sum of the current value and the passed interval
		public func addingTimeInterval(_ interval:UInt64) -> Self {
			return Self(RAW_native:self.RAW_native() + interval)
		}
		/// returns the time interval since Unix date
		public func timeIntervalSinceUnixDate() -> UInt64 {
			return self.RAW_native()
		}
		/// returns the time interval since the reference date (00:00:00 UTC on 1 January 2001)
		public func timeIntervalSinceReferenceDate() -> UInt64 {
			return self.RAW_native() - 978307200
		}
	}
	
	/// Initialize a new date based on the GMT timezone.
	public init() {
		self = Self(localTime:false)
	}

	/// Initialize a new date based on either the local timezone or the GMT timezone.
	public init(localTime:Bool) {
		// capture the current time.
		var ts = timespec()
		clock_gettime(CLOCK_REALTIME, &ts)
		let seconds = Double(ts.tv_sec)
		let nanoseconds = Double(ts.tv_nsec)
		let total_time = seconds + (nanoseconds / 1_000_000_000)
		if localTime {
			// apply the local timezone offset
			var now = time_t(ts.tv_sec)
			let loc = localtime(&now)!.pointee
			let offset = Double(loc.tm_gmtoff)
			self.init(RAW_native:total_time + offset)
		} else {
			// keep in UTC
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