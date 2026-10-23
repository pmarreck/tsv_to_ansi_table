#ifndef TSV_TO_ANSI_TABLE_H
#define TSV_TO_ANSI_TABLE_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef struct { const uint8_t *data; size_t len; } tsvat_slice;
typedef struct { const tsvat_slice *cells; size_t len; } tsvat_row;
typedef struct { uint8_t *data; size_t len; } tsvat_buffer;
typedef struct tsvat_context tsvat_context;
typedef struct {
	size_t terminal_width;
	tsvat_slice decimal;
	tsvat_slice glyphs_json;
	int color; /* 0: unstyled, 1: color; explicit --color overrides this default. */
	const tsvat_slice *args; /* CLI rendering options, excluding argv[0]. */
	size_t argc;
} tsvat_options;
enum {
	TSVAT_OK = 0, TSVAT_INVALID_ARGUMENT = 1, TSVAT_INVALID_OPTIONS = 2,
	TSVAT_INVALID_UTF8 = 3, TSVAT_RAGGED_ROW = 4, TSVAT_HEADER_COUNT = 5,
	TSVAT_TOO_MANY_OPTIONS = 6, TSVAT_TOO_NARROW = 7, TSVAT_INVALID_GLYPHS = 8,
	TSVAT_INVALID_SEED = 9, TSVAT_OUT_OF_MEMORY = 10, TSVAT_INVALID_STATE = 11,
	TSVAT_INTERNAL_ERROR = 12
};
enum { TSVAT_HELP = 1, TSVAT_ABOUT = 2, TSVAT_EXAMPLE = 4, TSVAT_NEEDS_SEED = 8 };

/* All inputs are borrowed for the call. NULL is valid only with zero length.
 * Non-NULL pointers must reference valid readable objects of the stated size.
 * Returned buffers are owned by this implementation; release with buffer_free.
 * Start output buffers empty. Never mix allocation/free across implementations.
 * Contexts own configuration and buffered data. Use each context on one thread
 * at a time. After any feed/finish error, destroy the context; continuing it
 * is unsupported. NULL output pointers return INVALID_ARGUMENT without work.
 * No operation reads the environment, terminal, clock, files or randomness. */
tsvat_options tsvat_default_options(void);
int tsvat_create(const tsvat_options *, tsvat_context **);
void tsvat_destroy(tsvat_context *);
unsigned tsvat_flags(const tsvat_context *);
int tsvat_push_row(tsvat_context *, tsvat_row, tsvat_buffer *);
/* One TSV record without LF; a trailing CR is removed. Embedded LF is invalid. */
int tsvat_push_tsv(tsvat_context *, tsvat_slice, tsvat_buffer *);
int tsvat_finish(tsvat_context *, tsvat_buffer *);
/* Rows include the header unless --no-header is supplied. Controls in cells,
 * including NUL, tab and newline, become U+FFFD; invalid UTF-8 is an error. */
int tsvat_render(const tsvat_options *, const tsvat_row *, size_t, tsvat_buffer *);
/* Only on a fresh context. A configured --seed wins over supplied_seed.
 * Both seed pointers reference 32 bytes; on a fresh valid context used_seed
 * reports the selected seed even if rendering fails. */
int tsvat_example(tsvat_context *, const uint8_t *supplied_seed, uint8_t *used_seed, tsvat_buffer *);
void tsvat_buffer_free(tsvat_buffer *);
const char *tsvat_error_message(int);
tsvat_slice tsvat_help(void);
tsvat_slice tsvat_about(void);
#ifdef __cplusplus
}
#endif
#endif
