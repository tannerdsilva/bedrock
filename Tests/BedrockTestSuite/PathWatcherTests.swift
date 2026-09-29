/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Testing
import bedrock
import bedrock_pathwatch

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

extension Tag {
	@Tag internal static var pathwatch:Self
}

extension BedrockTestSuite {

	@Suite("bedrock_pathwatch",
		.serialized,
		.tags(.bedrock, .pathwatch)
	)
	internal struct PathWatcherTests {

		// MARK: fixtures

		/// a temporary directory that holds the entries that a test monitors.
		private final class Fixture:@unchecked Sendable {

			/// the directory that is created for the test, and that the test may monitor.
			internal let directory:String

			/// a file inside the directory, which exists when the fixture is created.
			internal let file:String

			/// a path inside the directory that does not exist until a test creates it.
			internal let absentFile:String

			internal init() throws {
				var template = Array("/tmp/bedrock_pathwatch_XXXXXX".utf8CString)
				let madeDirectory = template.withUnsafeMutableBufferPointer { buffer -> String? in
					guard let made = mkdtemp(buffer.baseAddress!) else {
						return nil
					}
					return String(cString:made)
				}
				guard let directory = madeDirectory else {
					throw FixtureError.directoryCreationFailed
				}
				self.directory = directory
				file = directory + "/monitored.txt"
				absentFile = directory + "/absent.txt"
				_ = close(creat(file, 0o644))
			}

			deinit {
				_ = unlink(file)
				_ = unlink(absentFile)
				_ = rmdir(directory)
			}

			/// appends text to the monitored file. the file is closed by this call, which is what makes linux report a completed write.
			internal func append(_ text:String) {
				guard let stream = fopen(file, "a") else {
					return
				}
				_ = text.withCString { textPointer in
					return fputs(textPointer, stream)
				}
				_ = fclose(stream)
			}

			internal enum FixtureError:Swift.Error {
				case directoryCreationFailed
			}
		}

		// MARK: helpers

		/// opens a directory and counts the entries in it, which is how the leak test below observes the descriptors that the watcher holds.
		private static func openDescriptorCount() -> Int {
			guard let directory = opendir("/dev/fd") else {
				return -1
			}
			var count = 0
			while readdir(directory) != nil {
				count += 1
			}
			_ = closedir(directory)
			return count
		}

		// MARK: lifecycle

		@Test("pathwatch :: a watcher can be created and destroyed")
		func watcherLifecycle() throws {
			var watcher:PathWatcher? = try PathWatcher()
			#expect(watcher?.activeWatchCount == 0)
			watcher = nil
			#expect(watcher == nil)
		}

		@Test("pathwatch :: deliverable kinds reflect the platform")
		func deliverableKinds() {
			#if os(macOS)
			#expect(PathWatcher.deliverableKinds.contains(.modified))
			#expect(PathWatcher.deliverableKinds.contains(.attributesChanged))
			#expect(PathWatcher.deliverableKinds.contains(.removedSelf))
			#expect(PathWatcher.deliverableKinds.contains(.renamedSelf))
			#expect(PathWatcher.deliverableKinds.contains(.watchEnded))
			#expect(PathWatcher.deliverableKinds.contains(.appeared) == false)
			#expect(PathWatcher.deliverableKinds.contains(.disappeared) == false)
			#expect(PathWatcher.deliverableKinds.contains(.closedAfterWrite) == false)
			#elseif os(Linux)
			#expect(PathWatcher.deliverableKinds.contains(.appeared))
			#expect(PathWatcher.deliverableKinds.contains(.disappeared))
			#expect(PathWatcher.deliverableKinds.contains(.closedAfterWrite))
			#expect(PathWatcher.deliverableKinds.contains(.removedSelf))
			#expect(PathWatcher.deliverableKinds.contains(.renamedSelf))
			#endif
		}

		@Test("pathwatch :: registering a path that does not exist fails", .timeLimit(.minutes(1)))
		func registeringAbsentPathFails() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			do {
				_ = try await watcher.watch(path:Path(fixture.absentFile), kinds:[.modified])
				Issue.record("registering an absent path reported success")
			} catch {
				guard case .pathNotFound(let reportedPath) = error else {
					Issue.record("registering an absent path threw \(error)")
					return
				}
				#expect(String(reportedPath) == fixture.absentFile)
			}
		}

		@Test("pathwatch :: destroying a watch disarms it", .timeLimit(.minutes(1)))
		func destroyingWatchDisarms() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			do {
				let watch = try await watcher.watch(path:Path(fixture.file), kinds:[.modified])
				#expect(watch.id > 0)
				#expect(watcher.activeWatchCount == 1)
				_ = consume watch
			}
			// deregistration is applied by the servicing thread, so the count is only observed after that thread has been given the chance to apply it.
			for _ in 0..<100 {
				if watcher.activeWatchCount == 0 {
					break
				}
				try await Task.sleep(nanoseconds:10_000_000)
			}
			#expect(watcher.activeWatchCount == 0)
		}

		// MARK: delivery

		@Test("pathwatch :: a write is reported as modified", .timeLimit(.minutes(1)))
		func writeReportsModified() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			let watch = try await watcher.watch(path:Path(fixture.file), kinds:[.modified])
			fixture.append("hello")
			let event = try await watch.next()
			#expect(event?.kind.contains(.modified) == true)
			#expect(event?.child == nil)
			#expect(event?.cookie == 0)
			#expect(event?.isDirectory == false)
			#expect(event.map { String($0.path) } == fixture.file)
		}

		@Test("pathwatch :: a watch is armed before registration returns", .timeLimit(.minutes(1)))
		func changeImmediatelyAfterRegistrationIsDelivered() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			let watch = try await watcher.watch(path:Path(fixture.file), kinds:[.modified])
			// the write below races nothing, because the watch is already armed with the kernel when the call above returned.
			fixture.append("immediate")
			let event = try await watch.next()
			#expect(event?.kind.contains(.modified) == true)
		}

		@Test("pathwatch :: a permission change is reported as an attribute change", .timeLimit(.minutes(1)))
		func permissionChangeReportsAttributes() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			let watch = try await watcher.watch(path:Path(fixture.file), kinds:[.attributesChanged])
			#expect(chmod(fixture.file, 0o600) == 0)
			let event = try await watch.next()
			#expect(event?.kind.contains(.attributesChanged) == true)
		}

		@Test("pathwatch :: removing the monitored path is terminal", .timeLimit(.minutes(1)))
		func removalIsTerminal() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			let watch = try await watcher.watch(path:Path(fixture.file), kinds:[.removedSelf])
			#expect(unlink(fixture.file) == 0)
			let event = try await watch.next()
			#expect(event?.kind.contains(.removedSelf) == true)
			do {
				_ = try await watch.next()
				Issue.record("a watch that ended reported another event")
			} catch {
				guard case .watchEnded(let reportedPath, let reason) = error else {
					Issue.record("a watch that ended threw \(error)")
					return
				}
				#expect(String(reportedPath) == fixture.file)
				#expect(reason == .unlinked)
			}
		}

		@Test("pathwatch :: renaming the monitored path is terminal", .timeLimit(.minutes(1)))
		func renameIsTerminal() async throws {
			let fixture = try Fixture()
			let renamedPath = fixture.directory + "/renamed.txt"
			defer {
				_ = unlink(renamedPath)
			}
			let watcher = try PathWatcher()
			let watch = try await watcher.watch(path:Path(fixture.file), kinds:[.renamedSelf])
			#expect(rename(fixture.file, renamedPath) == 0)
			let event = try await watch.next()
			#expect(event?.kind.contains(.renamedSelf) == true)
			do {
				_ = try await watch.next()
				Issue.record("a watch that ended reported another event")
			} catch {
				guard case .watchEnded(_, let reason) = error else {
					Issue.record("a watch that ended threw \(error)")
					return
				}
				#expect(reason == .renamed)
			}
		}

		@Test("pathwatch :: a change inside a monitored directory is reported", .timeLimit(.minutes(1)))
		func directoryContentsChangeIsReported() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			let watch = try await watcher.watch(path:Path(fixture.directory), kinds:[.modified, .appeared])
			#expect(creat(fixture.absentFile, 0o644) >= 0)
			let event = try await watch.next()
			// the path of a change inside a directory is always the directory that was monitored.
			#expect(event.map { String($0.path) } == fixture.directory)
			#if os(Linux)
			// linux names the entry that changed, and describes that entry rather than the directory: the file that was created is not a directory.
			#expect(event?.kind.contains(.appeared) == true)
			#expect(event?.child == "absent.txt")
			#expect(event?.isDirectory == false)
			#elseif os(macOS)
			// macOS reports that the contents of the directory changed without naming the entry, so the change describes the directory itself.
			#expect(event?.kind.contains(.modified) == true)
			#expect(event?.child == nil)
			#expect(event?.isDirectory == true)
			#endif
		}

		@Test("pathwatch :: a watch that ends does not disturb its siblings", .timeLimit(.minutes(1)))
		func siblingWatchesAreIndependent() async throws {
			let fixture = try Fixture()
			let watcher = try PathWatcher()
			let ending = try await watcher.watch(path:Path(fixture.file), kinds:[.removedSelf])
			let surviving = try await watcher.watch(path:Path(fixture.directory), kinds:[.modified, .appeared])
			#expect(watcher.activeWatchCount == 2)
			// ending one watch must not disturb the registration that its sibling owns.
			#expect(unlink(fixture.file) == 0)
			let terminalEvent = try await ending.next()
			#expect(terminalEvent?.kind.contains(.removedSelf) == true)
			#expect(watcher.activeWatchCount == 1)
			// the surviving watch still reports the changes that it was armed for.
			#expect(creat(fixture.absentFile, 0o644) >= 0)
			#if os(Linux)
			// the removal above also changed the contents of the directory that the surviving watch describes, so its events are drained until the change that this test is waiting for arrives.
			var sawAppearance = false
			for _ in 0..<8 {
				guard let event = try await surviving.next() else {
					break
				}
				if event.kind.contains(.appeared), event.child == "absent.txt" {
					sawAppearance = true
					break
				}
			}
			#expect(sawAppearance)
			#elseif os(macOS)
			let survivingEvent = try await surviving.next()
			#expect(survivingEvent?.kind.contains(.modified) == true)
			#expect(survivingEvent?.child == nil)
			#expect(survivingEvent.map { String($0.path) } == fixture.directory)
			#endif
		}

		// MARK: resources

		@Test("pathwatch :: no descriptor is retained when a watcher is destroyed", .timeLimit(.minutes(1)))
		func descriptorsAreReturned() async throws {
			let fixture = try Fixture()
			let baseline = PathWatcherTests.openDescriptorCount()
			#expect(baseline > 0)
			let cycleCount = 25
			for _ in 0..<cycleCount {
				let watcher = try PathWatcher()
				do {
					let first = try await watcher.watch(path:Path(fixture.file), kinds:[.modified])
					let second = try await watcher.watch(path:Path(fixture.directory), kinds:[.modified])
					#expect(watcher.activeWatchCount == 2)
					// a live watcher holds descriptors of its own: the queue that it polls, a pipe that wakes it, and one descriptor for each monitored path.
					#expect(PathWatcherTests.openDescriptorCount() > baseline)
					_ = consume first
					_ = consume second
				}
			}
			// the watcher and its servicing thread are torn down when the final reference is released, and every descriptor that the watcher owned is released with them. a watcher that retained them would leave a hundred and twenty five descriptors behind after this many cycles, so the tolerance below absorbs only the handful of descriptors that the tests running in parallel with this one happen to hold, because the count is process wide rather than scoped to this test.
			let after = PathWatcherTests.openDescriptorCount()
			#expect(after <= baseline + cycleCount / 5)
		}
	}
}
