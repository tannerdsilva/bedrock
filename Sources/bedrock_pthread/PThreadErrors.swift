/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

/// thrown when a pthread cannot be created.
public struct PThreadLaunchFailure:Swift.Error {}

/// thrown when a pthread is unable to be canceled.
public enum PThreadCancellationFailure:Swift.Error {
	case alreadyCancelled
	case systemError
}
