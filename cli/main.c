#define _POSIX_C_SOURCE 200809L
#include "tsv_to_ansi_table.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>
#include <bcrypt.h>
#include <io.h>
#include <fcntl.h>
#endif
extern uint64_t tsv_console_width(void);
extern uint64_t tsv_windows_decimal(void);
static tsvat_slice bytes(const char *s) {
	return (tsvat_slice){(const uint8_t *)s, s ? strlen(s) : 0};
}
static const char *environment(const char *name) {
	const char *value = getenv(name);
	return value ? value : "";
}
static int write_bytes(const uint8_t *data, size_t count, FILE *file) {
	return (count && fwrite(data, 1, count, file) != count) || fflush(file) != 0;
}
static int write_output(tsvat_buffer *out) {
	int failed = write_bytes(out->data, out->len, stdout);
	tsvat_buffer_free(out);
	return failed;
}
static const char *decimal(void) {
	uint64_t native = tsv_windows_decimal();
	if (native) return native == 44 ? "," : native == 0x66b ? "٫" : ".";
#ifndef _WIN32
	FILE *pipe = popen("locale decimal_point 2>/dev/null", "r");
	if (pipe) {
		char value[16] = {0};
		size_t count = fread(value, 1, sizeof(value) - 1, pipe);
		int status = pclose(pipe);
		while (count && strchr(" \t\r\n", value[count - 1])) value[--count] = 0;
		char *start = value;
		while (*start && strchr(" \t\r\n", *start)) ++start;
		if (status == 0 && !strcmp(start, ",")) return ",";
		if (status == 0 && !strcmp(start, "٫")) return "٫";
	}
#endif
	return ".";
}
static int random_seed(uint8_t seed[32]) {
#ifdef _WIN32
	return BCryptGenRandom(NULL, seed, 32, BCRYPT_USE_SYSTEM_PREFERRED_RNG) != 0;
#else
	FILE *file = fopen("/dev/urandom", "rb");
	if (!file) return 1;
	int failed = fread(seed, 1, 32, file) != 32;
	return fclose(file) != 0 || failed;
#endif
}
static int run(int argc, char **argv) {
	int status = TSVAT_OK;
	const char *io_error = NULL;
	tsvat_context *ctx = NULL;
	tsvat_buffer out = {0};
	uint8_t *line = NULL;
	size_t capacity = 0;
	tsvat_slice *args = calloc((size_t)argc, sizeof(*args));
	if (!args) { status = TSVAT_OUT_OF_MEMORY; goto done; }
	for (int i = 1; i < argc; ++i) args[i - 1] = bytes(argv[i]);
	tsvat_options config = tsvat_default_options();
	uint64_t columns = tsv_console_width();
	char *end = NULL;
	const char *raw_width = environment("COLUMNS");
	unsigned long env_width = strtoul(raw_width, &end, 10);
	config.terminal_width = end != raw_width && !*end && env_width > 0 && env_width <= 10000 ? env_width : columns ? (size_t)columns : 80;
	config.decimal = bytes(decimal());
	config.glyphs_json = bytes(environment("TSV_TO_ANSI_TABLE_GLYPHS"));
	config.color = columns > 0 && !getenv("NO_COLOR") && strcmp(environment("TERM"), "dumb");
	config.args = args;
	config.argc = (size_t)argc - 1;
	status = tsvat_create(&config, &ctx);
	if (status) goto done;
	unsigned flags = tsvat_flags(ctx);
	if (flags & (TSVAT_HELP | TSVAT_ABOUT)) {
		tsvat_slice info = flags & TSVAT_HELP ? tsvat_help() : tsvat_about();
		if (write_bytes(info.data, info.len, stdout)) io_error = "OutputFailure";
		goto done;
	}
	if (flags & TSVAT_EXAMPLE) {
		uint8_t seed[32] = {0}, used[32];
		if ((flags & TSVAT_NEEDS_SEED) && random_seed(seed)) { io_error = "RandomFailure"; goto done; }
		status = tsvat_example(ctx, seed, used, &out);
		char report[73] = "seed=0x";
		const char *hex = "0123456789abcdef";
		for (size_t i = 0; i < 32; ++i) { report[7 + i * 2] = hex[used[i] >> 4]; report[8 + i * 2] = hex[used[i] & 15]; }
		report[71] = '\n';
		if (write_bytes((const uint8_t *)report, 72, stderr)) io_error = "OutputFailure";
		if (!status && !io_error && write_output(&out)) io_error = "OutputFailure";
		goto done;
	}
	for (;;) {
		size_t count = 0;
		int ch;
		while ((ch = fgetc(stdin)) != EOF && ch != '\n') {
			if (count == capacity) {
				if (capacity > SIZE_MAX / 2) { status = TSVAT_OUT_OF_MEMORY; goto done; }
				size_t next = capacity ? capacity * 2 : 4096;
				uint8_t *grown = realloc(line, next);
				if (!grown) { status = TSVAT_OUT_OF_MEMORY; goto done; }
				line = grown; capacity = next;
			}
			line[count++] = (uint8_t)ch;
		}
		if (ferror(stdin)) { io_error = "InputFailure"; goto done; }
		if (ch == EOF && count == 0) break;
		status = tsvat_push_tsv(ctx, (tsvat_slice){line, count}, &out);
		if (status) goto done;
		if (write_output(&out)) { io_error = "OutputFailure"; goto done; }
	}
	status = tsvat_finish(ctx, &out);
	if (!status && write_output(&out)) io_error = "OutputFailure";
done:
	tsvat_buffer_free(&out);
	tsvat_destroy(ctx);
	free(args);
	free(line);
	if (status || io_error) {
		fprintf(stderr, "tsv-to-ansi-table: %s\n", io_error ? io_error : tsvat_error_message(status));
		return 2;
	}
	return 0;
}
int main(int argc, char **argv) {
#ifdef _WIN32
	_setmode(_fileno(stdin), _O_BINARY);
	_setmode(_fileno(stdout), _O_BINARY);
	LPWSTR *wide = CommandLineToArgvW(GetCommandLineW(), &argc);
	if (!wide) return 2;
	argv = calloc((size_t)argc, sizeof(*argv));
	if (!argv) { LocalFree(wide); return 2; }
	for (int i = 0; i < argc; ++i) {
		int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide[i], -1, NULL, 0, NULL, NULL);
		if (!count || !(argv[i] = malloc((size_t)count))) {
			for (int j = 0; j < i; ++j) free(argv[j]);
			free(argv); LocalFree(wide); return 2;
		}
		WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide[i], -1, argv[i], count, NULL, NULL);
	}
	LocalFree(wide);
#endif
#if TSVAT_DEBUG
	fputs("\x1b[33mDEBUG BUILD!\x1b[0m\n", stderr);
#endif
	int status = run(argc, argv);
#ifdef _WIN32
	for (int i = 0; i < argc; ++i) free(argv[i]);
	free(argv);
#endif
	return status;
}
