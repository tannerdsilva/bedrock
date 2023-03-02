#include "lineparser.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// resize the buffer of an allocated lineparser_t
void lineparser_resize_up(lineparser_t *parser) {
	// double the size of the buffer
	parser->buffsize = parser->buffsize * 2;

	// capture the old buffer so it may be freed
	void *oldbuff = parser->intakebuff;
	
	// copy the data to the new buffer
	parser->intakebuff = memcpy(malloc(parser->buffsize), parser->intakebuff, parser->occupied);
	
	free(oldbuff);
}

// prepares the line parser to parse the next line. clears the previous line from the buffer
void lineparser_trim(lineparser_t *parser) {
	memcpy(parser->intakebuff, parser->intakebuff + parser->i, parser->buffsize - parser->i);
	parser->occupied = parser->occupied - parser->i;
	parser->i = 0;
}

// initialize a line parser
extern lineparser_t lp_init(const uint8_t*_Nullable match, const uint8_t matchlen) {
	lineparser_t newparser = {
		.buffsize = 1024,
		.intakebuff = malloc(1024),
		.i = 0,
		.occupied = 0,
		.matchsize = matchlen,
		.matched = 0
	};
	if (newparser.matchsize > 0) {
		newparser.match = memcpy(malloc(matchlen), match, matchlen);
	} else {
		newparser.match = NULL;
	}
	return newparser;
}

// send data into the line parser
extern void lp_intake(lineparser_t*_Nonnull parser, const uint8_t*_Nonnull intake_data, size_t data_len, datahandler_f dh) {
	if (parser->matchsize > 0) {
		// resize the parser to fit the data, if necessary
		while ((parser->occupied + data_len) > parser->buffsize) {
			lineparser_resize_up(parser);
		}
		
		// install the data in the intake buffer
		memcpy(parser->intakebuff + parser->occupied, intake_data, data_len);
		parser->occupied = parser->occupied + data_len;
		
		// parse the data
		while (parser->i < parser->occupied) {
			
			if (parser->match[parser->matched] == parser->intakebuff[parser->i]) {
				// if the current byte matches the next byte in the match sequence, increment the match counter
				parser->matched = parser->matched + 1;
				if (parser->matchsize == parser->matched) {

					// if the match counter has reached the end of the match sequence, fire the data handler and reset the match counter
					parser->matched = 0;
					parser->i = parser->i + 1;
					dh(parser->intakebuff, parser->i - parser->matchsize);
					lineparser_trim(parser);
				} else {
					parser->i = parser->i + 1;
				}
			} else {
				// if the current byte does not match the next byte in the match sequence, reset the match counter
				parser->i = parser->i + 1;
				parser->matched = 0;
			}
		}
	} else {
		dh(intake_data, data_len);
	}
}

// close the line parser from memory
extern void lp_close(lineparser_t*_Nonnull parser, datahandler_f dh) {
	if (parser->occupied > 0) {
		dh(parser->intakebuff, parser->occupied);
	}
	free(parser->intakebuff);
	if (parser->matchsize > 0) {
		free(parser->match);
	}
}

// close the line parser from memory while also discarding (and mishandling) any leftover data that may be in the buffer
extern void lp_close_dataloss(lineparser_t*_Nonnull parser) {
	free(parser->intakebuff);
	if (parser->matchsize > 0) {
		free(parser->match);
	}
}
