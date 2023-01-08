#include "common.h"
#include <chrono>
#include <stdio.h>
#include <stdarg.h>

using namespace std;

bool isLogEnabled;

void setLoggingEnabled(bool enabled)
{
    isLogEnabled = enabled;
}

long long int get_now()
{
    return chrono::duration_cast<std::chrono::milliseconds>(
               chrono::system_clock::now().time_since_epoch())
        .count();
}

void platform_log(const char *fmt, ...)
{
    if (isLogEnabled)
    {
        va_list args;
        va_start(args, fmt);
#ifdef __ANDROID__
        __android_log_vprint(ANDROID_LOG_VERBOSE, "ndk", fmt, args);
#elif defined(IS_WIN32)
        char *buf = new char[4096];
        std::fill_n(buf, 4096, '\0');
        _vsprintf_p(buf, 4096, fmt, args);
        OutputDebugStringA(buf);
        delete[] buf;
#else
        vprintf(fmt, args);
#endif
        va_end(args);
    }
}