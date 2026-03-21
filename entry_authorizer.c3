// JAM SDK - Authorizer Entry Point
// Only include this file in authorizer builds.
module jam::entry_auth;

import jam::types;
import jam::codec;
import jam::log;
import jam::authorizer;

// User hook
extern fn void is_authorized(authorizer::Ctx* ctx);

fn void jam_entry_is_authorized(char* arg_ptr, ulong arg_len) @export("jam_entry_is_authorized")
{
    codec::DecodeCtx dec = codec::decode_ctx_init(arg_ptr, arg_len);

    authorizer::Ctx ctx;

    ushort? ci = codec::decode_u16(&dec);
    if (catch ci)
    {
        log::err("JAM", "Authorizer: failed to decode core_index");
        return;
    }
    ctx._core_index = ci;

    is_authorized(&ctx);
}
