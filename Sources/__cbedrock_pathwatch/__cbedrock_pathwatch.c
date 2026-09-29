/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

#if defined(__linux__) && !defined(_GNU_SOURCE)
#define _GNU_SOURCE
#endif

#include "__cbedrock_pathwatch.h"
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

int __cbedrock_pathwatch_errno(void) {
	return errno;
}

int __cbedrock_pathwatch_wakeup_pipe(int *fds) {
#if defined(__linux__)
	return pipe2(fds, O_NONBLOCK | O_CLOEXEC);
#else
	if (pipe(fds) != 0) {
		return -1;
	}
	for (int i = 0; i < 2; i++) {
		if (fcntl(fds[i], F_SETFD, FD_CLOEXEC) != 0 || fcntl(fds[i], F_SETFL, O_NONBLOCK) != 0) {
			const int savedErrno = errno;
			close(fds[0]);
			close(fds[1]);
			errno = savedErrno;
			return -1;
		}
	}
	return 0;
#endif
}

#if defined(__linux__)

int __cbedrock_pathwatch_inotify_init(void) {
	return inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
}

int __cbedrock_pathwatch_inotify_add(int ifd, const char *path, uint32_t mask) {
	return inotify_add_watch(ifd, path, mask);
}

int __cbedrock_pathwatch_inotify_rm(int ifd, int wd) {
	return inotify_rm_watch(ifd, wd);
}

ssize_t __cbedrock_pathwatch_inotify_read(int ifd, void *buf, size_t len) {
	return read(ifd, buf, len);
}

#endif // __linux__
