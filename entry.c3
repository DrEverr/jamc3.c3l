// JAM SDK - Entry Points
// Provides the PVM entry point functions that the PolkaVM dispatch table maps to.
// These decode the raw arguments, construct typed context objects, and delegate
// to user-supplied hooks.
//
// The user must implement the following in their service module:
//   fn types::RefineResult refine(refine::Ctx* ctx)
//   fn void accumulate(accumulate::Ctx* ctx)
module jam::entry;

import jam::types;
import jam::codec;
import jam::log;
import jam::refine;
import jam::accumulate;

// ---------------------------------------------------------------------------
// User hooks - must be implemented by the service author.
// ---------------------------------------------------------------------------

extern fn types::RefineResult refine(refine::Ctx* ctx);
extern fn void accumulate(accumulate::Ctx* ctx);

// ---------------------------------------------------------------------------
// Refine entry point
// ---------------------------------------------------------------------------

fn types::RefineResult jam_entry_refine(char* arg_ptr, ulong arg_len) @export("jam_entry_refine")
{
    types::RefineResult empty = { null, 0 };

    codec::DecodeCtx dec = codec::decode_ctx_init(arg_ptr, arg_len);

    refine::Ctx ctx;

    uint? core_idx = codec::decode_var_u32(&dec);
    if (catch core_idx)
    {
        log::err("JAM", "Refine: failed to decode core_index");
        return empty;
    }
    ctx._core_index = core_idx;

    uint? wi_idx = codec::decode_var_u32(&dec);
    if (catch wi_idx)
    {
        log::err("JAM", "Refine: failed to decode work_item_index");
        return empty;
    }
    ctx._work_item_index = wi_idx;

    uint? svc_id = codec::decode_var_u32(&dec);
    if (catch svc_id)
    {
        log::err("JAM", "Refine: failed to decode service_id");
        return empty;
    }
    ctx._service_id = svc_id;

    codec::BlobSlice? blob = codec::decode_blob(&dec);
    if (catch blob)
    {
        log::err("JAM", "Refine: failed to decode work_payload");
        return empty;
    }
    ctx._work_payload     = blob.ptr;
    ctx._work_payload_len = blob.len;

    if (catch codec::decode_fixed(&dec, (char*)&ctx._work_package_hash, 32))
    {
        log::err("JAM", "Refine: failed to decode work_package_hash");
        return empty;
    }

    return refine(&ctx);
}

// ---------------------------------------------------------------------------
// Accumulate entry point
// ---------------------------------------------------------------------------

fn void jam_entry_accumulate(char* arg_ptr, ulong arg_len) @export("jam_entry_accumulate")
{
    codec::DecodeCtx dec = codec::decode_ctx_init(arg_ptr, arg_len);

    // 65 536-byte buffer for inputs; lives on this stack frame so that
    // zero-copy pointers returned by InputIter.next() remain valid for the
    // entire accumulate invocation.
    char[65536] inputs_buf;

    accumulate::Ctx ctx;

    uint? ts = codec::decode_var_u32(&dec);
    if (catch ts)
    {
        log::err("JAM", "Accumulate: failed to decode timeslot");
        return;
    }
    ctx._timeslot = ts;

    uint? svc_id = codec::decode_var_u32(&dec);
    if (catch svc_id)
    {
        log::err("JAM", "Accumulate: failed to decode service_id");
        return;
    }
    ctx._service_id = svc_id;

    ulong? n_inp = codec::decode_var_u64(&dec);
    if (catch n_inp)
    {
        log::err("JAM", "Accumulate: failed to decode num_inputs");
        return;
    }
    ctx._num_inputs     = n_inp;
    ctx._inputs_buf     = &inputs_buf;
    ctx._inputs_len     = 0;
    ctx._inputs_fetched = false;

    accumulate(&ctx);
}
