/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

#ifndef __CLIBBEDROCK_THREADS_H
#define __CLIBBEDROCK_THREADS_H

#include "__cbedrock_types.h"
#include <pthread.h>

#ifdef __APPLE__
typedef pthread_t _Nonnull __cbedrock_threads_t_type;
#else
typedef pthread_t __cbedrock_threads_t_type;
#endif

/// a type that describes a function that will be run as the main function of a pthread.
/// @param ws a pointer to the workspace that the pthread will use.
typedef void(* __cbedrock_threads_main_f)(__cbedrock_ptr_t ws);

/// an allocator for a pthread workspace.
/// @param arg the argument that was initially passed into the pthread. you can assume this is the only time you will be able to access this argument.
/// @return a pointer to the allocated workspace that the pthread will use.
typedef __cbedrock_ptr_t(* __cbedrock_threads_alloc_f)(__cbedrock_ptr_t arg);

/// a deallocator for a thread workspace.
/// @param ws a pointer to the workspace that the pthread used.
typedef void(* __cbedrock_threads_dealloc_f)(__cbedrock_ptr_t ws);

/// a cancel handler for a pthread. this is guaranteed to be called before the workspace deallocator.
/// @param ws a pointer to the workspace that the pthread used.
typedef void(* __cbedrock_threads_cancel_f)(__cbedrock_ptr_t ws);

/// a configuration for a pthread. this structure outlines the standardized way that work threads are created and managed.
typedef struct __cbedrock_threads_config_t {
	/// argument to pass into the workspace allocator.
	__cbedrock_ptr_t ____aa;
	/// workspace allocator.
	__cbedrock_threads_alloc_f _Nonnull ____af;
	// main function to run.
	__cbedrock_threads_main_f _Nonnull ____mf;
	// cancel handler.
	__cbedrock_threads_cancel_f _Nonnull ____cr;
	// workspace deallocator.
	__cbedrock_threads_dealloc_f _Nonnull ____df;
} __cbedrock_threads_config_t;

/// create a pthread configuration.
/// @param _ the argument to pass into the workspace allocator function.
/// @param __ the workspace allocator to run.
/// @param ___ the main function to run as the 'work' of the pthread.
/// @param ____ the cancel handler to run if the thread is cancelled.
/// @param _____ the workspace deallocator to run.
__cbedrock_threads_config_t *_Nonnull __cbedrock_threads_config_init (
	__cbedrock_ptr_t _,
	__cbedrock_threads_alloc_f _Nonnull __,
	__cbedrock_threads_main_f _Nonnull ___,
	__cbedrock_threads_cancel_f _Nonnull ____,
	__cbedrock_threads_dealloc_f _Nonnull _____
);

/// create a new pthread.
/// @param _ the configuration to use for the pthread lifecycle. this pointer will be freed internally by this function.
/// @param __ the result of the pthread creation.
/// @return the pthread that was created if result is 0, undefined otherwise.
__cbedrock_threads_t_type __cbedrock_threads_config_run(
	const __cbedrock_threads_config_t *_Nonnull _,
	int *_Nonnull __
);

#endif // __CLIBBEDROCK_THREADS_H