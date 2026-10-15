#include <stdint.h>
#include <stdio.h>
FILE *tsv_stdin(void) { return stdin; }
FILE *tsv_stdout(void) { return stdout; }
FILE *tsv_stderr(void) { return stderr; }
#ifdef _WIN32
#include <windows.h>
uint64_t tsv_console_width(void) {
	CONSOLE_SCREEN_BUFFER_INFO info;
	HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
	DWORD mode;
	if (!GetConsoleMode(h, &mode)) return 0;
	SetConsoleMode(h, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
	return GetConsoleScreenBufferInfo(h, &info) ? (uint64_t)(info.srWindow.Right - info.srWindow.Left + 1) : 80;
}
uint64_t tsv_windows_decimal(void) {
	WCHAR value[8];
	return GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SDECIMAL, value, 8) ? value[0] : 46;
}
#else
#include <unistd.h>
#include <sys/ioctl.h>
uint64_t tsv_console_width(void) {
	struct winsize size;
	if (!isatty(STDOUT_FILENO)) return 0;
	return ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 && size.ws_col ? size.ws_col : 80;
}
uint64_t tsv_windows_decimal(void) { return 0; }
#endif
