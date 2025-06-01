/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

#include "__cbedrock_future.h"
#include "__cbedrock_identified_list.h"

#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/// an internal tool to help with the identified list iterator.
struct ____cbedrock_future_identified_list_tool {
	const uint8_t _;
	const __cbedrock_optr_t __;
};

__cbedrock_future_wait_t __cbedrock_future_wait_t_init_struct() {
	__cbedrock_future_wait_t __0 = {
		.____c = NULL,
		.____sy = false,
		.____r = NULL,
		.____e = NULL,
		.____v = NULL,
		.____ic = false
	};
	return __0;
}

/// create a new synchronous waiter for a future.
/// @param _ the context pointer to pass to the result handler when it comes time to fire.
/// @param __ the handler to call when the future is complete with a valid result.
/// @param ___ the handler to call when the future is complete with an error.
/// @param ____ the handler to call when the future is cancelled and a result will never be available.
/// @param _____ a pointer to the memory space that the waiter structure will be initialized into.
/// @return a pointer to the waiter structure on the heap.
void ____cbedrock_future_wait_t_init_sync(
	__cbedrock_optr_t _,
	__cbedrock_future_result_val_handler_f __,
	__cbedrock_future_result_err_handler_f ___,
	__cbedrock_future_result_cncl_handler_f ____,
	__cbedrock_future_wait_ptr_t _____
) {
	const __cbedrock_future_wait_t __0 = {
		.____c = _,
		.____sy = true,
		.____r = (__cbedrock_ptr_t)__,
		.____e = (__cbedrock_ptr_t)___,
		.____v = (__cbedrock_ptr_t)____,
		.____ic = false
	};
	memcpy(_____, &__0, sizeof(__cbedrock_future_wait_t));
	if (pthread_mutex_init(&_____->____rm, NULL) != 0) {
		printf("bedrock future internal error: couldn't initialize future sync_wait mutex\n");
		abort();
	}
	pthread_mutex_lock(&_____->____rm);
}

/// create a new asynchronous waiter for a future.
/// @param _ the context pointer to pass to the result handler when it comes time to fire.
/// @param __ the handler to call when the future is complete with a valid result.
/// @param ___ the handler to call when the future is complete with an error.
/// @param ____ the handler to call when the future is cancelled and a result will never be available.
/// @return the waiter structure.
__cbedrock_future_wait_ptr_t ____cbedrock_future_wait_t_init_async(__cbedrock_optr_t _, __cbedrock_future_result_val_handler_f __, __cbedrock_future_result_err_handler_f ___, __cbedrock_future_result_cncl_handler_f ____) {
	__cbedrock_future_wait_t __0 = {
		.____c = _,
		.____sy = false,
		.____r = (__cbedrock_ptr_t)__,
		.____e = (__cbedrock_ptr_t)___,
		.____v = (__cbedrock_ptr_t)____,
		.____ic = false
	};
	__cbedrock_future_wait_ptr_t __1 = malloc(sizeof(__cbedrock_future_wait_t));
	memcpy(__1, &__0, sizeof(__cbedrock_future_wait_t));
	return __1;
}

/// @brief unlock and destroy a synchronous waiter result for a future.
/// @param _ the waiter to destroy.
void ____cbedrock_future_wait_t_unlock_destroy_sync(__cbedrock_future_wait_ptr_t _) {
	pthread_mutex_unlock(&_->____rm);
	pthread_mutex_destroy(&_->____rm);
}

/// @brief destroy an asynchronous waiter for a future.
/// @param _ the waiter to destroy.
void ____cbedrock_future_wait_t_destroy_async(__cbedrock_future_wait_ptr_t _) {
	free((void*)_);
}

void ____cbedrock_future_identified_list_cancel_iterator(
	const uint64_t _,
	const __cbedrock_ptr_t __,
	const __cbedrock_optr_t ___
) {
	if (((__cbedrock_future_wait_ptr_t)__)->____sy == true) {
		pthread_mutex_unlock(&((__cbedrock_future_wait_ptr_t)__)->____rm);
	} else {
		((__cbedrock_future_wait_ptr_t)__)->____v(((__cbedrock_future_wait_ptr_t)__)->____c);
		____cbedrock_future_wait_t_destroy_async((__cbedrock_future_wait_ptr_t)__);
	}
}

bool __cbedrock_future_t_broadcast_cancel(
	const __cbedrock_future_ptr_t _
) {	
	pthread_mutex_lock(&_->____m);
	uint8_t expected_complete = __CBEDROCK_FUTURE_STATUS_PEND;
	if (atomic_compare_exchange_strong_explicit(&_->____s, &expected_complete, __CBEDROCK_FUTURE_STATUS_CANCEL, memory_order_acq_rel, memory_order_relaxed) == false) {
		pthread_mutex_unlock(&_->____m);
		return false;
	}
	__cbedrock_identified_list_iterate_consume_zero(_->____wi, ____cbedrock_future_identified_list_cancel_iterator, NULL, false);
	pthread_mutex_unlock(&_->____m);
	return true;
}

void ____cbedrock_future_identified_list_close(
	const uint64_t _,
	const __cbedrock_ptr_t __,
	const __cbedrock_ptr_t ___
) {
	free((void*)__);
}

__cbedrock_future_ptr_t __cbedrock_future_t_init() {
	__cbedrock_future_ptr_t __0 = malloc(sizeof(__cbedrock_future_t));
	atomic_store_explicit(&__0->____s, __CBEDROCK_FUTURE_STATUS_PEND, memory_order_release);
	if (pthread_mutex_init(&__0->____m, NULL) != 0) {
		printf("bedrock future internal error: couldn't initialize future mutex\n");
		abort();
	}
	__cbedrock_identified_list_pair_t __1 = __cbedrock_identified_list_init();
	__cbedrock_ptr_t __2 = malloc(sizeof(__cbedrock_identified_list_pair_t));
	memcpy(__2, &__1, sizeof(__cbedrock_identified_list_pair_t));
	__0->____wi = __2;
	return __0;
}

void __cbedrock_future_t_destroy(
	__cbedrock_future_ptr_t _,
	const __cbedrock_optr_t __,
	const _Nonnull __cbedrock_future_result_val_handler_f ___,
	const _Nonnull __cbedrock_future_result_err_handler_f ____
) {
	pthread_mutex_lock(&_->____m);
	int8_t __0 = atomic_load_explicit(&_->____s, memory_order_acquire);
	switch (__0) {
		case __CBEDROCK_FUTURE_STATUS_PEND:
			__cbedrock_identified_list_iterate_consume_zero(_->____wi, ____cbedrock_future_identified_list_cancel_iterator, NULL, false);
			break;
		case __CBEDROCK_FUTURE_STATUS_RESULT:
			___(atomic_load_explicit(&_->____rt, memory_order_acquire), atomic_load_explicit(&_->____rv, memory_order_acquire), __);
			break;
		case __CBEDROCK_FUTURE_STATUS_THROW:
			____(atomic_load_explicit(&_->____rt, memory_order_acquire), atomic_load_explicit(&_->____rv, memory_order_acquire), __);
			break;
		case __CBEDROCK_FUTURE_STATUS_CANCEL:
			break;
		default:
			printf("bedrock future internal error: invalid future status\n");
			abort();
	}
	pthread_mutex_unlock(&_->____m);
	pthread_mutex_lock(&_->____m);
	__cbedrock_identified_list_close(_->____wi, ____cbedrock_future_identified_list_close, NULL);
	pthread_mutex_unlock(&_->____m);
	pthread_mutex_destroy(&_->____m);
	free(_);
}

__cbedrock_optr_t __cbedrock_future_t_wait_sync_register(
	const __cbedrock_future_ptr_t _,
	const __cbedrock_optr_t __,
	const _Nonnull __cbedrock_future_result_val_handler_f ___,
	const _Nonnull __cbedrock_future_result_err_handler_f ____,
	const _Nonnull __cbedrock_future_result_cncl_handler_f _____,
	const __cbedrock_future_wait_ptr_t ______
) {
	pthread_mutex_lock(&_->____m);
	uint8_t __1;
	__cbedrock_optr_t __2;
	uint64_t __3;
	checkStat:
		switch (atomic_load_explicit(&_->____s, memory_order_acquire)) {
			case __CBEDROCK_FUTURE_STATUS_PEND:
				____cbedrock_future_wait_t_init_sync(__, ___, ____, _____, ______);
				atomic_store_explicit(&______->____i, __cbedrock_identified_list_insert(_->____wi, ______), memory_order_release);
				goto proceedToBlock;
			case __CBEDROCK_FUTURE_STATUS_RESULT:
				__1 = atomic_load_explicit(&_->____rt, memory_order_acquire);
				__2 = atomic_load_explicit(&_->____rv, memory_order_acquire);
				___(__1, __2, __);
				goto returnTime;
			case __CBEDROCK_FUTURE_STATUS_THROW:
				__1 = atomic_load_explicit(&_->____rt, memory_order_acquire);
				__2 = atomic_load_explicit(&_->____rv, memory_order_acquire);
				____(__1, __2, __);
				goto returnTime;
			case __CBEDROCK_FUTURE_STATUS_CANCEL:
				_____(__);
				goto returnTime;
			default:
				printf("bedrock future internal error: invalid future status\n");
				abort();
		}
	returnTime:
		pthread_mutex_unlock(&_->____m);
		return (__cbedrock_optr_t)NULL;
	proceedToBlock:
		pthread_mutex_unlock(&_->____m);
		return (__cbedrock_optr_t)______;
}

/// returns the unique waiter ID for a future waiter.
/// @param _ the unique pointer that was returned from `__cbedrock_future_t_wait_sync_register`.
/// @return the unique waiter ID.
uint64_t __cbedrock_future_wait_id_get(
	const __cbedrock_optr_t _
) {
	return atomic_load_explicit(&((__cbedrock_future_wait_ptr_t)_)->____i, memory_order_acquire);
}

void __cbedrock_future_t_wait_sync_block(
	const __cbedrock_future_ptr_t _,
	const __cbedrock_ptr_t __
) {
	pthread_mutex_lock(&((__cbedrock_future_wait_ptr_t)__)->____rm);
	pthread_mutex_lock(&_->____m);
	uint8_t __1;
	__cbedrock_optr_t __2;
	if (atomic_load_explicit(&((__cbedrock_future_wait_ptr_t)__)->____ic, memory_order_acquire) == true) {
		((__cbedrock_future_wait_ptr_t)__)->____v(((__cbedrock_future_wait_ptr_t)__)->____c);
	} else {
		switch (atomic_load_explicit(&_->____s, memory_order_acquire)) {
			case __CBEDROCK_FUTURE_STATUS_RESULT:
				__1 = atomic_load_explicit(&_->____rt, memory_order_acquire);
				__2 = atomic_load_explicit(&_->____rv, memory_order_acquire);
				((__cbedrock_future_wait_ptr_t)__)->____r(__1, __2, ((__cbedrock_future_wait_ptr_t)__)->____c);
				break;
			case __CBEDROCK_FUTURE_STATUS_THROW:
				__1 = atomic_load_explicit(&_->____rt, memory_order_acquire);
				__2 = atomic_load_explicit(&_->____rv, memory_order_acquire);
				((__cbedrock_future_wait_ptr_t)__)->____e(__1, __2, ((__cbedrock_future_wait_ptr_t)__)->____c);
				break;
			case __CBEDROCK_FUTURE_STATUS_CANCEL:
				((__cbedrock_future_wait_ptr_t)__)->____v(((__cbedrock_future_wait_ptr_t)__)->____c);
				break;
			default:
				printf("bedrock future internal error: invalid future status\n");
				abort();
		}
	}
	pthread_mutex_unlock(&_->____m);
	____cbedrock_future_wait_t_unlock_destroy_sync(((__cbedrock_future_wait_ptr_t)__));
}

/// @brief a optional pointer to a future waiter.
typedef __cbedrock_future_wait_t *_Nullable __cbedrock_future_wait_optr_t;

bool __cbedrock_future_wait_sync_invalidate(
	const __cbedrock_future_ptr_t _,
	const uint64_t __
) {
	pthread_mutex_lock(&_->____m);
	const int8_t __0 = atomic_load_explicit(&_->____s, memory_order_acquire);
	__cbedrock_future_wait_optr_t __1;
	switch (__0) {
		case __CBEDROCK_FUTURE_STATUS_PEND:
			goto cancelWaiter;
		case __CBEDROCK_FUTURE_STATUS_RESULT:
			goto returnFalse;
		case __CBEDROCK_FUTURE_STATUS_THROW:
			goto returnFalse;
		case __CBEDROCK_FUTURE_STATUS_CANCEL:
			goto returnFalse;
		default:
			printf("bedrock future internal error: invalid future status\n");
			abort();
	}
	cancelWaiter:
		__1 = (__cbedrock_future_wait_optr_t)__cbedrock_identified_list_remove(_->____wi, __);
		if (__1 == NULL) {
			pthread_mutex_unlock(&_->____m);
			return false;
		} else {
			atomic_store_explicit(&((__cbedrock_future_wait_ptr_t)__1)->____ic, true, memory_order_release);
			pthread_mutex_unlock(&_->____m);
			pthread_mutex_unlock(&__1->____rm);
			return true;
		}
	returnFalse:
		pthread_mutex_unlock(&_->____m);
		return false;
}

uint64_t __cbedrock_future_t_wait_async(
	const __cbedrock_future_ptr_t _,
	const __cbedrock_optr_t __,
	const _Nonnull __cbedrock_future_result_val_handler_f ___,
	const _Nonnull __cbedrock_future_result_err_handler_f ____,
	const _Nonnull __cbedrock_future_result_cncl_handler_f _____
) {
	const __cbedrock_future_wait_ptr_t __0 = ____cbedrock_future_wait_t_init_async(__, ___, ____, _____);
	pthread_mutex_lock(&_->____m);
	const int8_t __1 = atomic_load_explicit(&_->____s, memory_order_acquire);
	uint64_t __2;
	uint8_t __3;
	__cbedrock_optr_t __4;
	checkStat:
	switch (__1) {
		case __CBEDROCK_FUTURE_STATUS_PEND:
			__2 = __cbedrock_identified_list_insert(_->____wi, (__cbedrock_ptr_t)__0);
			atomic_store_explicit(&__0->____i, __2, memory_order_release);
			goto returnTimeWaiting;
		case __CBEDROCK_FUTURE_STATUS_RESULT:
			__3 = atomic_load_explicit(&_->____rt, memory_order_acquire);
			__4 = atomic_load_explicit(&_->____rv, memory_order_acquire);
			___(__3, __4, __);
			goto returnTimeNoWait;
		case __CBEDROCK_FUTURE_STATUS_THROW:
			__3 = atomic_load_explicit(&_->____rt, memory_order_acquire);
			__4 = atomic_load_explicit(&_->____rv, memory_order_acquire);
			____(__3, __4, __);
			goto returnTimeNoWait;
		case __CBEDROCK_FUTURE_STATUS_CANCEL:
			_____(NULL);
			goto returnTimeNoWait;
		default:
			printf("bedrock future internal error: invalid future status\n");
			abort();
	}
	returnTimeNoWait:
		pthread_mutex_unlock(&_->____m);
		____cbedrock_future_wait_t_destroy_async(__0);
		return 0;
	returnTimeWaiting:
		pthread_mutex_unlock(&_->____m);
		if (__2 == 0) {
			printf("bedrock future internal error: future waiter should never have zero id. this is an internal error\n");
			abort();
		}
		return __2;
}

bool __cbedrock_future_t_wait_async_invalidate(
	const __cbedrock_future_ptr_t _,
	const uint64_t __
) {
	pthread_mutex_lock(&_->____m);
	const int8_t __0 = atomic_load_explicit(&_->____s, memory_order_acquire);
	__cbedrock_optr_t __1;
	switch (__0) {
		case __CBEDROCK_FUTURE_STATUS_PEND:
			goto cancelWaiter;
		case __CBEDROCK_FUTURE_STATUS_RESULT:
			goto returnFalse;
		case __CBEDROCK_FUTURE_STATUS_THROW:
			goto returnFalse;
		case __CBEDROCK_FUTURE_STATUS_CANCEL:
			goto returnFalse;
		default:
			printf("bedrock future internal error: invalid future status\n");
			abort();
	}
	cancelWaiter:
		__1 = __cbedrock_identified_list_remove(_->____wi, __);
		pthread_mutex_unlock(&_->____m);
		if (__1 == NULL) {
			return false;
		}
		((__cbedrock_future_wait_ptr_t)__1)->____v(((__cbedrock_future_wait_ptr_t)(__1))->____c);
		____cbedrock_future_wait_t_destroy_async(__1);
		return true;
	returnFalse:
		pthread_mutex_unlock(&_->____m);
		return false;
}

void ____cbedrock_future_identified_list_val_iterator(
	const uint64_t _,
	const __cbedrock_ptr_t wptr,
	const __cbedrock_ptr_t ___
) {
	if (((__cbedrock_future_wait_ptr_t)wptr)->____sy == true) {
		pthread_mutex_unlock(&((__cbedrock_future_wait_ptr_t)wptr)->____rm);
	} else {
		((__cbedrock_future_wait_ptr_t)wptr)->____r(((struct ____cbedrock_future_identified_list_tool*)___)->_, ((struct ____cbedrock_future_identified_list_tool*)___)->__, ((__cbedrock_future_wait_ptr_t)wptr)->____c);
		____cbedrock_future_wait_t_destroy_async((__cbedrock_future_wait_ptr_t)wptr);
	}
}

void ____cbedrock_future_identified_list_throw_iterator(
	const uint64_t _,
	const __cbedrock_ptr_t wptr,
	const __cbedrock_ptr_t ___
) {
	if (((__cbedrock_future_wait_ptr_t)wptr)->____sy == true) {
		pthread_mutex_unlock(&((__cbedrock_future_wait_ptr_t)wptr)->____rm);
	} else {
		((__cbedrock_future_wait_ptr_t)wptr)->____e(((struct ____cbedrock_future_identified_list_tool*)___)->_, ((struct ____cbedrock_future_identified_list_tool*)___)->__, ((__cbedrock_future_wait_ptr_t)wptr)->____c);
		____cbedrock_future_wait_t_destroy_async((__cbedrock_future_wait_ptr_t)wptr);
	}
}

bool __cbedrock_future_t_broadcast_res_val(
	const __cbedrock_future_ptr_t _,
	const uint8_t __,
	const __cbedrock_optr_t ___
) {
	pthread_mutex_lock(&_->____m);
    uint8_t expected_complete = __CBEDROCK_FUTURE_STATUS_PEND;
	if (atomic_compare_exchange_strong_explicit(&_->____s, &expected_complete, __CBEDROCK_FUTURE_STATUS_RESULT, memory_order_acq_rel, memory_order_relaxed) == false) {
		pthread_mutex_unlock(&_->____m);
		return false;
	}
	atomic_store_explicit(&_->____rv, ___, memory_order_release);
	atomic_store_explicit(&_->____rt, __, memory_order_release);
	struct ____cbedrock_future_identified_list_tool __0 = {
		._ = __,
		.__ = ___
	};
	__cbedrock_identified_list_iterate_consume_zero(_->____wi, ____cbedrock_future_identified_list_val_iterator, &__0, false);
	pthread_mutex_unlock(&_->____m);
	return true;
}

bool __cbedrock_future_t_broadcast_res_throw(
	const __cbedrock_future_ptr_t _,
	const uint8_t __,
	const __cbedrock_optr_t ___
) {
	pthread_mutex_lock(&_->____m);
	uint8_t expected_complete = __CBEDROCK_FUTURE_STATUS_PEND;
	if (atomic_compare_exchange_strong_explicit(&_->____s, &expected_complete, __CBEDROCK_FUTURE_STATUS_THROW, memory_order_acq_rel, memory_order_relaxed) == false) {
		pthread_mutex_unlock(&_->____m);
		return false;
	}
	atomic_store_explicit(&_->____rv, ___, memory_order_release);
	atomic_store_explicit(&_->____rt, __, memory_order_release);
	struct ____cbedrock_future_identified_list_tool __0 = {
		._ = __,
		.__ = ___
	};
	__cbedrock_identified_list_iterate_consume_zero(_->____wi, ____cbedrock_future_identified_list_throw_iterator, &__0, false);
	pthread_mutex_unlock(&_->____m);
	return true;
}