#ifndef CLIBBEDROCK_LP_H
#define CLIBBEDROCK_LP_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// the data handler type that consumes parsed data after a separator sequence has been found
typedef void(^_Nonnull datahandler)(const uint8_t *_Nonnull, const size_t);

// the line parser struct that encapsulates the complete state
typedef struct lineparser {
	uint8_t*_Nullable match;
	uint8_t matchsize; //small pattern strings only.
	uint8_t matched;
	
	uint8_t *_Nullable intakebuff;
	size_t buffsize;
	
	size_t i;
	size_t occupied;
} lineparser_t;

// initialize a line parser. a line parser can be initialized with a sequence of bytes that we are parsing by.
extern lineparser_t lp_init(const uint8_t*_Nullable match, const uint8_t matchlen);
extern void lp_intake(lineparser_t*_Nonnull parser, const uint8_t*_Nonnull intake_data, size_t data_len, const datahandler dh);

// remove the lineparser from memory, firing the data handler (if necessary) to handle the remaining data in the input buffer.
extern void lp_close(lineparser_t*_Nonnull parser, datahandler dh);

// remove the lineparser from memory without handling the remaining data that was stored in the input buffer.
extern void lp_close_dataloss(lineparser_t*_Nonnull parser);
#endif
