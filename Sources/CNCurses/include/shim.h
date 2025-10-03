#ifndef CNCURSES_SHIM_H
#define CNCURSES_SHIM_H

// Ensure we use system ncurses, not homebrew or other versions
#define _XOPEN_SOURCE_EXTENDED 1

// Use the system ncurses - explicitly use the macOS system path
#include <ncurses.h>

#endif // CNCURSES_SHIM_H
