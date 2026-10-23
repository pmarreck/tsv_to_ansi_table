#include "tsv_to_ansi_table.h"
#include <assert.h>
#include <stdint.h>
#include <string.h>

#define S(text) { (const uint8_t *)(text), sizeof(text) - 1 }
static void equal(tsvat_buffer *out, const char *expected) {
	assert(out->len == strlen(expected));
	if (out->len) assert(!memcmp(out->data, expected, out->len));
	tsvat_buffer_free(out);
	assert(!out->data && !out->len);
	tsvat_buffer_free(out);
}
int main(void) {
	tsvat_options options = tsvat_default_options();
	const tsvat_slice args[] = { S("--plain") };
	options.args = args;
	options.argc = 1;
	const tsvat_slice header[] = { S("Name"), S("N") };
	const tsvat_slice data[] = { S("a"), S("12") };
	const tsvat_row rows[] = { {header, 2}, {data, 2} };
	tsvat_buffer output = {0};
	assert(tsvat_render(&options, rows, 2, &output) == TSVAT_OK);
	equal(&output, "Name   N\na     12\n");
	assert(tsvat_render(&options, NULL, 0, &output) == TSVAT_OK);
	equal(&output, "");
	assert(tsvat_render(&options, NULL, 1, &output) == TSVAT_INVALID_ARGUMENT);
	assert(!output.data && !output.len);
	const tsvat_slice bad[] = { {NULL, 1} };
	const tsvat_row bad_row = {bad, 1};
	assert(tsvat_render(&options, &bad_row, 1, &output) == TSVAT_INVALID_ARGUMENT);
	const tsvat_slice invalid[] = { S("\xff") };
	const tsvat_row invalid_row = {invalid, 1};
	assert(tsvat_render(&options, &invalid_row, 1, &output) == TSVAT_INVALID_UTF8);
	const tsvat_slice binary[] = { S("a\0b\t\nx") };
	const tsvat_row binary_row = {binary, 1};
	assert(tsvat_render(&options, &binary_row, 1, &output) == TSVAT_OK);
	equal(&output, "a�b��x\n");
	const tsvat_slice fixed[] = { S("--plain"), S("--widths"), S("4,2") };
	options.args = fixed;
	options.argc = 3;
	tsvat_context *context = NULL;
	assert(tsvat_create(&options, &context) == TSVAT_OK);
	assert(tsvat_push_row(context, rows[0], &output) == TSVAT_OK);
	equal(&output, "");
	assert(tsvat_push_row(context, rows[1], &output) == TSVAT_OK);
	equal(&output, "Name   N\na     12\n");
	assert(tsvat_finish(context, &output) == TSVAT_OK);
	equal(&output, "");
	assert(tsvat_finish(context, &output) == TSVAT_INVALID_STATE);
	assert(tsvat_push_row(context, rows[1], &output) == TSVAT_INVALID_STATE);
	tsvat_destroy(context);
	tsvat_destroy(NULL);
	assert(tsvat_create(NULL, &context) == TSVAT_INVALID_ARGUMENT);
	assert(!context);
	assert(tsvat_render(&options, rows, SIZE_MAX, &output) == TSVAT_INVALID_ARGUMENT);
	const tsvat_slice oversized[] = { {(const uint8_t *)"x", SIZE_MAX} };
	const tsvat_row oversized_row = {oversized, 1};
	assert(tsvat_render(&options, &oversized_row, 1, &output) == TSVAT_INVALID_ARGUMENT);
	options.argc = SIZE_MAX;
	assert(tsvat_create(&options, &context) == TSVAT_INVALID_ARGUMENT);
	assert(!context);
	/* Retained configuration and auto-width rows must outlive caller buffers. */
	uint8_t option[] = "--plain", title[] = "Name", value[] = "a";
	const tsvat_slice mutable_args[] = {{option, sizeof(option) - 1}};
	const tsvat_slice mutable_header[] = {{title, sizeof(title) - 1}, S("N")};
	const tsvat_slice mutable_data[] = {{value, sizeof(value) - 1}, S("12")};
	options = tsvat_default_options();
	options.args = mutable_args;
	options.argc = 1;
	assert(tsvat_create(&options, &context) == TSVAT_OK);
	option[2] = 'X';
	assert(tsvat_push_row(context, (tsvat_row){mutable_header, 2}, &output) == TSVAT_OK);
	equal(&output, "");
	assert(tsvat_push_row(context, (tsvat_row){mutable_data, 2}, &output) == TSVAT_OK);
	equal(&output, "");
	title[0] = 'X'; value[0] = 'b';
	assert(tsvat_finish(context, &output) == TSVAT_OK);
	equal(&output, "Name   N\na     12\n");
	tsvat_destroy(context);
	options.args = args;
	assert(tsvat_create(&options, &context) == TSVAT_OK);
	assert(tsvat_push_tsv(context, (tsvat_slice)S("Name\tN\r"), &output) == TSVAT_OK);
	equal(&output, "");
	assert(tsvat_push_tsv(context, (tsvat_slice)S("a\t12"), &output) == TSVAT_OK);
	equal(&output, "");
	assert(tsvat_finish(context, &output) == TSVAT_OK);
	equal(&output, "Name   N\na     12\n");
	tsvat_destroy(context);
	assert(tsvat_create(&options, &context) == TSVAT_OK);
	assert(tsvat_push_tsv(context, (tsvat_slice)S("a\nb"), &output) == TSVAT_INVALID_ARGUMENT);
	assert(tsvat_finish(context, &output) == TSVAT_INVALID_STATE);
	tsvat_destroy(context);
	options.glyphs_json = (tsvat_slice){NULL, 1};
	assert(tsvat_create(&options, &context) == TSVAT_INVALID_ARGUMENT);
	assert(!context);
	return 0;
}
