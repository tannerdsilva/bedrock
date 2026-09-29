/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

#ifndef __CLIBBEDROCK_PATHWATCH_H
#define __CLIBBEDROCK_PATHWATCH_H

#include "__cbedrock_types.h"
#include <stdint.h>
#include <sys/types.h>

/// returns the value of the errno variable for the calling thread.
/// swift is unable to reference the errno macro on linux, so this function style wrapper is used on every platform for parity.
/// - returns: the value of the errno variable.
int __cbedrock_pathwatch_errno(void);

/// creates a pipe that is appropriate for use as a watcher wakeup channel.
/// both ends of the pipe are placed into non-blocking mode so that neither signaling nor draining can ever block a caller, and both ends are marked close-on-exec.
/// - note: linux reaches for `pipe2` with `O_NONBLOCK|O_CLOEXEC` because glibc's `fcntl` is variadic and therefore unavailable to swift. darwin has no `pipe2`, so the flags are applied with `fcntl` immediately after the pipe is created.
/// - parameter fds: a buffer of at least two elements that receives the reading and writing file handles respectively.
/// - returns: 0 on success. a non-zero value is returned if an unexpected error is encountered, and errno is set. no file handles are leaked on failure.
int __cbedrock_pathwatch_wakeup_pipe(int *fds);

#if defined(__linux__)

#include <sys/inotify.h>

/// the inotify event masks that the swift layer translates into ``FileEventKind`` values.
/// the values are taken directly from the system header so that the swift side never restates them.
enum {
	__CBEDROCK_PATHWATCH_IN_MODIFY      = IN_MODIFY,
	__CBEDROCK_PATHWATCH_IN_ATTRIB      = IN_ATTRIB,
	__CBEDROCK_PATHWATCH_IN_CLOSE_WRITE = IN_CLOSE_WRITE,
	__CBEDROCK_PATHWATCH_IN_MOVED_FROM  = IN_MOVED_FROM,
	__CBEDROCK_PATHWATCH_IN_MOVED_TO    = IN_MOVED_TO,
	__CBEDROCK_PATHWATCH_IN_CREATE      = IN_CREATE,
	__CBEDROCK_PATHWATCH_IN_DELETE      = IN_DELETE,
	__CBEDROCK_PATHWATCH_IN_DELETE_SELF = IN_DELETE_SELF,
	__CBEDROCK_PATHWATCH_IN_MOVE_SELF   = IN_MOVE_SELF,
	__CBEDROCK_PATHWATCH_IN_UNMOUNT     = IN_UNMOUNT,
	__CBEDROCK_PATHWATCH_IN_Q_OVERFLOW  = IN_Q_OVERFLOW,
	__CBEDROCK_PATHWATCH_IN_IGNORED     = IN_IGNORED,
	__CBEDROCK_PATHWATCH_IN_ISDIR       = IN_ISDIR
};

/// creates an inotify instance that is non-blocking and close-on-exec.
/// - returns: the inotify file handle on success, or -1 with errno set.
int __cbedrock_pathwatch_inotify_init(void);

/// adds a watch for the given path to the given inotify instance.
/// - parameter ifd: the inotify file handle.
/// - parameter path: the null terminated filesystem path to watch.
/// - parameter mask: the event mask to watch for.
/// - returns: the watch descriptor on success, or -1 with errno set.
int __cbedrock_pathwatch_inotify_add(int ifd, const char *path, uint32_t mask);

/// removes a watch from the given inotify instance.
/// - parameter ifd: the inotify file handle.
/// - parameter wd: the watch descriptor to remove.
/// - returns: 0 on success, or -1 with errno set.
int __cbedrock_pathwatch_inotify_rm(int ifd, int wd);

/// reads pending inotify records into the given buffer.
/// each successful read returns zero or more complete records; the kernel never splits a record across reads, and it reports `EINVAL` rather than truncating a record when the buffer is too small to hold the next one.
/// - parameter ifd: the inotify file handle.
/// - parameter buf: the buffer to read into.
/// - parameter len: the capacity of the buffer.
/// - returns: the number of bytes read on success, or -1 with errno set. a return value of -1 with errno set to `EAGAIN` indicates that no records are pending.
ssize_t __cbedrock_pathwatch_inotify_read(int ifd, void *buf, size_t len);

#endif // __linux__

#endif // __CLIBBEDROCK_PATHWATCH_H
