/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

// thats all she wrote
#ifndef __CBEDROCK_TYPES_H
#define __CBEDROCK_TYPES_H

#include <sys/types.h>

/// a non-optional pointer
typedef void*_Nonnull __cbedrock_ptr_t;

/// a constant non-optional pointer
typedef const void*_Nonnull __cbedrock_cptr_t;

/// an optional pointer
typedef void*_Nullable __cbedrock_optr_t;

/// a constant optional pointer
typedef const void*_Nonnull __cbedrock_coptr_t;

#endif // __CBEDROCK_TYPES_H