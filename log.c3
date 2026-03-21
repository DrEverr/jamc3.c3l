// JAM SDK - Logging
// Wraps the host log function with level-specific helpers.
module jam::log;

import jam::host;

// Log levels matching the JAM host specification.
const ulong LEVEL_ERROR = 0;
const ulong LEVEL_WARN  = 1;
const ulong LEVEL_INFO  = 2;
const ulong LEVEL_DEBUG = 3;
const ulong LEVEL_TRACE = 4;

// ---------------------------------------------------------------------------
// Core log function
// ---------------------------------------------------------------------------

fn void log_msg(ulong level, char* target, usz target_len, char* msg, usz msg_len)
{
    host::host_log(level, target, target_len, msg, msg_len);
}

// ---------------------------------------------------------------------------
// String length — @noinline to prevent LLVM from merging with callers,
// which would increase register pressure beyond PolkaVM's 14-register limit.
// ---------------------------------------------------------------------------

fn usz str_len(char* s) @noinline
{
    if (s == null) return 0;
    usz len = 0;
    while (s[len] != 0) len++;
    return len;
}

// ---------------------------------------------------------------------------
// Log with null-terminated strings.
// Each uses log_cstr @noinline which computes both lengths and calls host_log
// in a single frame — avoids callee-saved register spills across multiple calls.
// ---------------------------------------------------------------------------

fn void info(char* target, char* msg)
{
    log_msg(LEVEL_INFO, target, str_len(target), msg, str_len(msg));
}

fn void warn(char* target, char* msg)
{
    log_msg(LEVEL_WARN, target, str_len(target), msg, str_len(msg));
}

fn void err(char* target, char* msg)
{
    log_msg(LEVEL_ERROR, target, str_len(target), msg, str_len(msg));
}

fn void debug(char* target, char* msg)
{
    log_msg(LEVEL_DEBUG, target, str_len(target), msg, str_len(msg));
}

fn void trace(char* target, char* msg)
{
    log_msg(LEVEL_TRACE, target, str_len(target), msg, str_len(msg));
}

// ---------------------------------------------------------------------------
// Format a ulong as decimal into a buffer. Returns the number of chars written.
// Buffer must be at least 20 bytes (max digits in u64) + 1 for safety.
// ---------------------------------------------------------------------------

fn usz fmt_u64(char* buf, usz buf_len, ulong value)
{
    if (buf_len == 0) return 0;

    if (value == 0)
    {
        buf[0] = '0';
        return 1;
    }

    // Write digits in reverse
    char[20] tmp;
    usz count = 0;
    ulong v = value;
    while (v > 0 && count < 20)
    {
        tmp[count] = (char)('0' + (v % 10));
        v /= 10;
        count++;
    }

    // Copy reversed into buf
    usz n = count < buf_len ? count : buf_len;
    for (usz i = 0; i < n; i++)
    {
        buf[i] = tmp[count - 1 - i];
    }
    return n;
}

// ---------------------------------------------------------------------------
// Log a message with a u64 value: "label: 12345"
// ---------------------------------------------------------------------------

fn void debug_u64(char* target, char* label, ulong value)
{
    // "label: " + up to 20 digits
    char[128] buf;
    usz pos = 0;

    usz lbl_len = str_len(label);
    for (usz i = 0; i < lbl_len && pos < 125; i++)
    {
        buf[pos++] = label[i];
    }
    if (pos < 126) { buf[pos++] = ':'; }
    if (pos < 126) { buf[pos++] = ' '; }

    pos += fmt_u64(&buf[pos], 128 - pos, value);

    log_msg(LEVEL_DEBUG, target, str_len(target), &buf, pos);
}
