/// The Delta struct makes it easy to compare additions or subtractions of a list of Hashable objects.
public struct Delta<T> where T:Hashable {
	/// the Type that is being compared
	typealias DeltaType = T
	
	/// the hashed entities that exist in the starting dataset
	let start:Set<DeltaType>
	
	/// hashed entities that are exclusive to the starting dataset
	/// - items found in this set were not found in the ending dataset
	let exclusiveStart:Set<DeltaType>
	/// hashed entities that are common to both the starting and ending dataset
	let common:Set<DeltaType>
	/// hashed entities that are exclusive to the ending dataset
	/// - items found in this set were not found in the beginning dataset
	let end:Set<DeltaType>
	
	/// the hashed entities that exist in the ending dataset
	let exclusiveEnd:Set<DeltaType>
	
	/// Initialize a Delta struct based on two collections of the same Type.
	init<S>(start startSeq:S, end endSeq:S) where S:Sequence, S.Element == T {
		let start = Set(startSeq)
		let end = Set(endSeq)
		let differing = start.symmetricDifference(end)
		let exclusiveStart = differing.subtracting(end)
		let exclusiveEnd = differing.subtracting(start)
		let common = start.intersection(end)
		
		self.start = start
		self.exclusiveStart = exclusiveStart
		self.common = common
		self.end = end
		self.exclusiveEnd = exclusiveEnd
	}
}
