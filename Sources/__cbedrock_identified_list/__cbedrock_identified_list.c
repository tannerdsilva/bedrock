/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

#include "__cbedrock_identified_list.h"
#include "__cbedrock_types.h"

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

/// initial size of the hash table.
#define INITIAL_HASH_TABLE_SIZE 16
/// maximum size of the hash table.
#define MAX_HASH_TABLE_SIZE 2097152
/// load factor threshold for resizing up (e.g., 0.75 means resize when 75% full).
#define RESIZE_UP_FACTOR 0.75
/// load factor threshold for resizing down (e.g., 0.25 means resize when 25% full).
#define RESIZE_DOWN_FACTOR 0.25
/// factor by which the hash table size increases upon resizing.
#define RESIZE_MULTIPLIER 2

static size_t HF_(uint64_t key) {
	return key;
}

static void resize_hashtable(
	__cbedrock_identified_list_pair_ptr_t _,
	const size_t __
) {
	__cbedrock_identified_list_ptr_t* __0 = calloc(__, sizeof(__cbedrock_identified_list_ptr_t));
	memset(__0, 0, __ * sizeof(__cbedrock_identified_list_ptr_t));
	__cbedrock_identified_list_ptr_t __1 = _->____o;
	while (__1 != NULL) {
		size_t __2 = HF_(__1->____k) % __;
		size_t __3 = __2;
		size_t __4 = 0;
		while (__0[__2] != NULL) {
			__4++;
			__2 = (__3 + __4) % __;
		}
		__0[__2] = __1;
		__1 = __1->____n;
	}
	free(_->____ht);
	_->____ht = __0;
	_->____hn = __;
}

__cbedrock_identified_list_pair_t __cbedrock_identified_list_init() {
	__cbedrock_identified_list_pair_t __0 = {
		.____ht = calloc(INITIAL_HASH_TABLE_SIZE, sizeof(__cbedrock_identified_list_ptr_t)),
		.____hn = INITIAL_HASH_TABLE_SIZE,
		.____i = 0,
		.____idi = 0,
		.____p = NULL,
		.____o = NULL
	};
	pthread_mutex_init(&__0.____m, NULL);
	return __0;
}

uint64_t ____increment_overflow_guard(
	uint64_t *_Nonnull __
) {
	if ((*__) == UINT64_MAX) {
		*__ = 1;
		return 1;
	}
	(*__)++;
	return *__;
}

uint64_t __cbedrock_identified_list_insert(
	const __cbedrock_identified_list_pair_ptr_t _,
	const __cbedrock_ptr_t __
) {
	pthread_mutex_lock(&_->____m);
	double __0 = (double)(_->____i + 1) / _->____hn;
	if (__0 > RESIZE_UP_FACTOR && _->____hn < MAX_HASH_TABLE_SIZE) {
		size_t __1 = _->____hn * RESIZE_MULTIPLIER;
		if (__1 > MAX_HASH_TABLE_SIZE) {
			__1 = MAX_HASH_TABLE_SIZE;
		}
		resize_hashtable(_, __1);
	}
	uint64_t __1 = ____increment_overflow_guard(&_->____idi);
	size_t __2 = HF_((size_t)__1) % _->____hn;
	size_t __3 = __2;
	size_t __4 = 0;
	while (_->____ht[__2] != NULL) {
		__4++;
		__2 = (__3 + __4) % _->____hn;
	}
	const __cbedrock_identified_list_t __5 = {
		.____k = __1,
		.____d = __,
		.____n = NULL,
		.____p = _->____p
	};
	__cbedrock_identified_list_ptr_t __6 = malloc(sizeof(__cbedrock_identified_list_t));
	memcpy(__6, &__5, sizeof(__cbedrock_identified_list_t));
	_->____ht[__2] = __6;
	if (_->____p != NULL) {
		_->____p->____n = __6;
	}
	_->____p = __6;
	if (_->____o == NULL) {
		_->____o = __6;
	}
	_->____i++;
	pthread_mutex_unlock(&_->____m);
	return __1;
}

__cbedrock_optr_t __cbedrock_identified_list_remove(
	const __cbedrock_identified_list_pair_ptr_t _,
	const uint64_t __
) {
	pthread_mutex_lock(&_->____m);
	size_t __0 = HF_((size_t)__) % _->____hn;
	const size_t __1 = __0;
	size_t __2 = 0;
	__cbedrock_identified_list_ptr_t __3 = NULL;
	while (_->____ht[__0] != NULL) {
		if (_->____ht[__0]->____k == __) {
			__3 = _->____ht[__0];
			break;
		}
		__2++;
		__0 = (__1 + __2) % _->____hn;
	}
	if (__3 == NULL) {
		pthread_mutex_unlock(&_->____m);
		return (__cbedrock_optr_t)NULL;
	}
	_->____ht[__0] = NULL;
	__0 = (__0 + 1) % _->____hn;
	while (_->____ht[__0] != NULL) {
		__cbedrock_identified_list_ptr_t __1 = _->____ht[__0];
		_->____ht[__0] = NULL;
		size_t __4 = HF_(__1->____k) % _->____hn;
		size_t __5 = 0;
		while (_->____ht[__4] != NULL) {
			__5++;
			__4 = (__4 + 1) % _->____hn;
		}
		_->____ht[__4] = __1;
		__0 = (__0 + 1) % _->____hn;
	}
	if (__3->____p != NULL) {
		__3->____p->____n = __3->____n;
	} else {
		_->____o = __3->____n;
	}
	if (__3->____n != NULL) {
		__3->____n->____p = __3->____p;
	} else {
		_->____p = __3->____p;
	}
	__cbedrock_optr_t __4 = __3->____d;
	free(__3);
	_->____i--;
	if (((double)((double)_->____i / (double)_->____hn)) < RESIZE_DOWN_FACTOR && _->____hn > INITIAL_HASH_TABLE_SIZE) {
		size_t __5 = _->____hn / RESIZE_MULTIPLIER;
		if (__5 < INITIAL_HASH_TABLE_SIZE) {
			__5 = INITIAL_HASH_TABLE_SIZE;
		}
		resize_hashtable(_, __5);
	}
	pthread_mutex_unlock(&_->____m);
	return __4;
}

void __cbedrock_identified_list_iterate(
	const __cbedrock_identified_list_pair_ptr_t _,
	const __cbedrock_identified_list_iterator_f __,
	const __cbedrock_optr_t ___,
	const bool ____
) {
	pthread_mutex_lock(&_->____m);
	__cbedrock_identified_list_ptr_t __0 = _->____o;
	while (__0 != NULL) {
		__(__0->____k, __0->____d, ___);
		__0 = __0->____n;
	}
	if (____ == false) {
		pthread_mutex_unlock(&_->____m);
	}
}

void __cbedrock_identified_list_close(
        const __cbedrock_identified_list_pair_ptr_t _,
        const __cbedrock_identified_list_iterator_f __,
        const __cbedrock_optr_t ___
) {
        pthread_mutex_lock(&_->____m);
        __cbedrock_identified_list_ptr_t __0 = _->____o;
        while (__0 != NULL) {
			__(__0->____k, __0->____d, ___);
			__cbedrock_identified_list_ptr_t __1 = __0;
			__0 = __0->____n;
			free(__1);
        }
        free(_->____ht);
        pthread_mutex_unlock(&_->____m);
        pthread_mutex_destroy(&_->____m);
}

void __cbedrock_identified_list_iterate_consume_zero(
	const __cbedrock_identified_list_pair_ptr_t _,
	const __cbedrock_identified_list_iterator_f __,
	const __cbedrock_optr_t ___,
	const bool ____
) {
	pthread_mutex_lock(&_->____m);
	__cbedrock_identified_list_ptr_t __0 = _->____o;
	while (__0 != NULL) {
		__(__0->____k, __0->____d, ___);
		__cbedrock_identified_list_ptr_t __1 = __0;
		__0 = __0->____n;
		free(__1);
	}
	_->____o = NULL;
	_->____p = NULL;
	_->____i = 0;
	if (____ == false) {
		pthread_mutex_unlock(&_->____m);
	}
}

void __cbedrock_identified_list_iterate_hanginglock_complete(
	const __cbedrock_identified_list_pair_ptr_t _
) {
	pthread_mutex_unlock(&_->____m);
}
