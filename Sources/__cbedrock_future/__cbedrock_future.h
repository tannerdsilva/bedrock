/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

#ifndef __CLIBBEDROCK_FUTURE_H
#define __CLIBBEDROCK_FUTURE_H

#include "__cbedrock_types.h"

#include <pthread.h>
#include <stdint.h>
#include <stdbool.h>

/// status values.
typedef enum __cbedrock_future_status_t {
	/// pending status (future not fufilled).
	__CBEDROCK_FUTURE_STATUS_PEND = 0,
	/// result status (future fufilled normally).
	__CBEDROCK_FUTURE_STATUS_RESULT = 1,
	/// thrown status (future fufilled with an error).
	__CBEDROCK_FUTURE_STATUS_THROW = 2,
	/// cancel status (future was not fufilled and will NOT fufill in the future).
	__CBEDROCK_FUTURE_STATUS_CANCEL = 3,
} __cbedrock_future_status_t;

// handler types -----
/// result handler function.
/// @param _ result type field.
/// @param __ result pointer field (optional).
/// @param ___ function context pointer (optional).
typedef void(* _Nonnull __cbedrock_future_result_val_handler_f)(
	const uint8_t _,
	const __cbedrock_optr_t __,
	const __cbedrock_optr_t ___
);

/// error handler function.
/// @param _ error type field.
/// @param __ error pointer field (optional).
/// @param ___ function context pointer (optional).
typedef void(* _Nonnull __cbedrock_future_result_err_handler_f)(
	const uint8_t _,
	const __cbedrock_optr_t __,
	const __cbedrock_optr_t ___
);

/// cancel handler function.
/// @param _ function context pointer (optional).
typedef void(* _Nonnull __cbedrock_future_result_cncl_handler_f)(
	const __cbedrock_optr_t _
);

/// used to represent a thread that is synchronously waiting and blocking for the result of a future.
typedef struct __cbedrock_future_wait_t {
	/// the context pointer that will be transparenly passed to the result handler.
	const __cbedrock_optr_t ____c;
	/// reflects the synchronous state of the future waiter. true for sync, false for async.
	const bool ____sy;
	
	/// the mutex that is used to block the thread until the future is complete. this is only used if the waiter is synchronous.
	pthread_mutex_t ____rm;

	/// the result handler to call when the future is complete.
	const __cbedrock_future_result_val_handler_f ____r;
	/// the error handler to call when the future is complete.
	const __cbedrock_future_result_err_handler_f ____e;
	/// the cancel handler to call when the future is cancelled and a result will never be available.
	const __cbedrock_future_result_cncl_handler_f ____v;

	/// the waiter ID for the future waiter.
	_Atomic uint64_t ____i;

	/// has the individual waiter instance been cancelled?
	_Atomic bool ____ic;
} __cbedrock_future_wait_t;

/// initialize a synchronous future waiter.
__cbedrock_future_wait_t __cbedrock_future_wait_t_init_struct();

/// a non-optional pointer to a future waiter.
typedef __cbedrock_future_wait_t *_Nonnull __cbedrock_future_wait_ptr_t;

/// a future that will either succeed with a pointer type and pointer, or fail with an error type and pointer.
typedef struct __cbedrock_future {
	// internal status
	_Atomic uint8_t ____s;
	// internal mutex
	pthread_mutex_t ____m;
	
	// result type
	_Atomic uint8_t ____rt;
	// result value
	_Atomic __cbedrock_optr_t ____rv;

	// waiters
	__cbedrock_ptr_t ____wi;
} __cbedrock_future_t;

/// a pointer to a future.
typedef __cbedrock_future_t*_Nonnull __cbedrock_future_ptr_t;

/// initialize a future.
/// @return pointer to the heap space containing the newly initialized future.
__cbedrock_future_ptr_t __cbedrock_future_t_init();

/// destroy a future. behavior is undefined if this is called while the future is still in use.
/// @param _ pointer to the future to deallocate.
/// @param __ the context pointer to pass to the result handler.
/// @param ___ the result handler to call when the future is complete.
/// @param ____ the error handler to call when the future is complete.
/// @return void is returned after the future is safely deallocated.
void __cbedrock_future_t_destroy(
	__cbedrock_future_ptr_t _,
	const __cbedrock_optr_t __,
	const _Nonnull __cbedrock_future_result_val_handler_f ___,
	const _Nonnull __cbedrock_future_result_err_handler_f ____
);

/// register a synchronous waiter for a future. a synchronous waiter is used to describe the process where a thread is blocked and the result handling functions are called from that same blocking thread. the registration thread and the thread that blocks may be different. NOTE: this function does not block the calling thread, instead, it registers the waiting information without blocking and allows the calling thread to determine when to block and handle the result.
/// @param _ the future to wait for.
/// @param __ the context pointer to pass to the result handler.
/// @param ___ the result handler to call when the future is complete.
/// @param ____ the error handler to call when the future is complete.
/// @param _____ the cancel handler to call when the future is cancelled.
/// @param ______ the storage space for the waiter struct.
/// @return a unique pointer that is used to wait or cancel waiting synchronously. the contents of the pointer are not to be accessed. if the returned pointer is NULL, the future is already complete, and the result handler will be called immediately. NOTE: if a non-null pointer is returned, the user is OBLIGATED to call the `__cbedrock_future_wait_sync_invalidate` function to deallocate the waiter.
__cbedrock_optr_t __cbedrock_future_t_wait_sync_register(
	const __cbedrock_future_ptr_t _,
	const __cbedrock_optr_t __,
	const _Nonnull __cbedrock_future_result_val_handler_f ___,
	const _Nonnull __cbedrock_future_result_err_handler_f ____,
	const _Nonnull __cbedrock_future_result_cncl_handler_f _____,
	const __cbedrock_future_wait_ptr_t ______
);

/// returns the unique waiter ID for a future waiter.
/// @param _ the unique pointer that was returned from `__cbedrock_future_t_wait_sync_register`.
/// @return the unique waiter ID.
uint64_t __cbedrock_future_wait_id_get(
	const __cbedrock_optr_t _
);

/// block the calling thread until the future is complete. the result handlers registered in `__cbedrock_future_t_wait_sync_register` will be called from the thread that calls (and possibly blocks) on this function.
/// @param _ the future to wait for.
/// @param __ the unique waiter pointer (must not be NULL)
/// @return void is returned after the future is complete. results of the future are passed into the handlers that were provided at the time of registration.
void __cbedrock_future_t_wait_sync_block(
	const __cbedrock_future_ptr_t _,
	const __cbedrock_ptr_t __
);

/// cancel a synchronous waiter for a future.
/// @param _ the future to cancel the waiter for.
/// @param __ the unique waiter pointer to cancel.
bool __cbedrock_future_wait_sync_invalidate(
	const __cbedrock_future_ptr_t _,
	const uint64_t __
);

/// register completion handlers for the future and return immediately. handler functions will be called from the thread that completes the future.
/// @param _ the future to wait for.
/// @param __ the context pointer to pass to the result handler.
/// @param ___ the result handler to call (from another thread) when the future is complete.
/// @param ____ the error handler to call (from another thread) when the future is complete.
/// @param _____ the cancel handler to call (from another thread) when the future is cancelled.
/// @return a unique identifier for the waiter. this unique identifier can be used to cancel the waiter later. if the future is already complete, the result handler will be called immediately, and zero is returned.
uint64_t __cbedrock_future_t_wait_async(
	const __cbedrock_future_ptr_t _,
	const __cbedrock_optr_t __,
	const _Nonnull __cbedrock_future_result_val_handler_f ___,
	const _Nonnull __cbedrock_future_result_err_handler_f ____,
	const _Nonnull __cbedrock_future_result_cncl_handler_f _____
);

/// cancel an asynchronous waiter for a future. after calling this function, you can rest assured that the result handlers will not be fired for the specified waiter. however, it is possible that a result becomes available during the course of calling this function, and such conditions are reported by the return value.
/// @param _ the future to cancel the waiter for.
/// @param __ the unique waiter identifier to cancel.
/// @return a boolean value indicating if the cancellation was successful. if the waiter was already complete and the handler functions were fired, this function will return false.
bool __cbedrock_future_t_wait_async_invalidate(
	const __cbedrock_future_ptr_t _,
	const uint64_t __
);

/// broadcast a completion result to all threads waiting on the future.
/// @param _ the future to broadcast to.
/// @param __ the result type - an 8 bit value.
/// @param ___ the result value - an optional pointer.
/// @return whether the broadcast was successful.
bool __cbedrock_future_t_broadcast_res_val(
	const __cbedrock_future_ptr_t _,
	const uint8_t __,
	const __cbedrock_optr_t ___
);

/// broadcast a completion result to all threads waiting on the future.
/// @param _ the future to broadcast to.
/// @param __ the result type - an 8 bit value.
/// @param ___ the result value - an optional pointer.
/// @return whether the broadcast was successful.
bool __cbedrock_future_t_broadcast_res_throw(
	const __cbedrock_future_ptr_t _,
	const uint8_t __,
	const __cbedrock_optr_t ___
);

/// broadcast a cancellation result to all threads waiting on the future.
/// @param _ the future to broadcast to.
/// @return whether the broadcast was successful.
bool __cbedrock_future_t_broadcast_cancel(
	const __cbedrock_future_ptr_t _
);

#endif // __CLIBBEDROCK_FUTURE_H