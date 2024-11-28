#include "common.h"
#include <stdio.h>
#include <stdarg.h>
#include <algorithm>

bool isLogEnabled;

void setLoggingEnabled(bool enabled) noexcept
{
        isLogEnabled = enabled;
}

void platform_log(const char* fmt, ...) noexcept
{
        if (isLogEnabled)
        {
                va_list args;
                va_start(args, fmt);
#ifdef __ANDROID__
                __android_log_vprint(ANDROID_LOG_VERBOSE, "ndk", fmt, args);
#elif defined(IS_WIN32)
                char* buf = new char[4096];
                std::fill_n(buf, 4096, '\0');
                _vsprintf_p(buf, 4096, fmt, args);
                OutputDebugStringA(buf);
                delete[] buf;
#else
                // vprintf(fmt, args);
                vfprintf(stderr, fmt, args);
#endif
                va_end(args);
        }
}
