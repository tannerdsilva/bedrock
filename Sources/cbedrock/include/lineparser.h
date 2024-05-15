#ifndef CLIBBEDROCK_LP_H
#define CLIBBEDROCK_LP_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// the data handler type that consumes parsed data after a separator sequence has been found
typedef void(^_Nonnull _cbedrock_datahandler_f)(const uint8_t *_Nonnull, const size_t);

// the line parser struct that encapsulates the complete state
typedef struct _cbedrock_lineparser {
	uint8_t*_Nullable match;
	uint8_t matchsize; //small pattern strings only.
	uint8_t matched;
	
	uint8_t *_Nullable intakebuff;
	size_t buffsize;
	
	size_t i;
	size_t occupied;
} _cbedrock_lineparser_t;

// initialize a line parser. a line parser can be initialized with a sequence of bytes that we are parsing by.
extern _cbedrock_lineparser_t _cbedrock_lp_init(const uint8_t*_Nullable match, const uint8_t matchlen);
extern void _cbedrock_lp_intake(_cbedrock_lineparser_t*_Nonnull parser, const uint8_t*_Nonnull intake_data, size_t data_len, const _cbedrock_datahandler_f dh);

// remove the lineparser from memory, firing the data handler (if necessary) to handle the remaining data in the input buffer.
extern void _cbedrock_lp_close(_cbedrock_lineparser_t*_Nonnull parser, _cbedrock_datahandler_f dh);

// remove the lineparser from memory without handling the remaining data that was stored in the input buffer.
extern void _cbedrock_lp_close_dataloss(_cbedrock_lineparser_t*_Nonnull parser);
#endif
