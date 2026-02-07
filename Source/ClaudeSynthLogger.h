#ifndef __ClaudeSynthLogger_h__
#define __ClaudeSynthLogger_h__

#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdarg.h>

// Simple file logger for debugging
static void ClaudeLog(const char* format, ...) {
    FILE* f = fopen("/tmp/claudesynth.log", "a");
    if (f) {
        time_t now = time(NULL);
        char timestr[64];
        strftime(timestr, sizeof(timestr), "%H:%M:%S", localtime(&now));
        fprintf(f, "[%s] ", timestr);

        va_list args;
        va_start(args, format);
        vfprintf(f, format, args);
        va_end(args);

        fprintf(f, "\n");
        fclose(f);
    }
}

#endif
