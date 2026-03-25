// JAM SDK - High-level Service API
// Convenience functions for common service operations.
module jam::service;

import jam::host;
import jam::types;
import jam::codec;
import jam::result;
import jam::log;

// Get remaining gas
fn types::Gas gas_remaining()
{
    return host::host_gas();
}

// Get own service info
fn types::ServiceInfo? service_info()
{
    types::ServiceInfo info;
    ulong ret = host::host_info(types::HOST_NONE, (char*)&info);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
    return info;
}

// Get info for a specific service
fn types::ServiceInfo? service_info_of(types::ServiceId id)
{
    types::ServiceInfo info;
    ulong ret = host::host_info((ulong)id, (char*)&info);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
    return info;
}

// Get own service balance
fn types::Balance? balance()
{
    types::ServiceInfo info = service_info()!;
    return info.balance;
}

// Build a RefineResult to return from refine().
// The entry point returns this struct, placing ptr in a0 and len in a1
// at PVM halt time.
fn types::RefineResult refine_ok(char* ptr, usz len)
{
    types::RefineResult r = { ptr, len };
    return r;
}

fn types::RefineResult refine_empty()
{
    types::RefineResult r = { null, 0 };
    return r;
}

// Transfer tokens to another service
fn void? transfer(types::ServiceId receiver, types::Balance amount, types::Gas gas_limit, types::Memo* memo)
{
    ulong ret = host::host_transfer(
        (ulong)receiver,
        amount,
        gas_limit,
        (char*)memo
    );
    if (ret == types::HOST_WHO)  return result::UNREACHABLE~;
    if (ret == types::HOST_CASH) return result::INSUFFICIENT_BALANCE~;
    if (ret == types::HOST_LOW)  return result::HOST_ERROR~;
}

// Create a state checkpoint (accumulate only)
fn types::Gas checkpoint()
{
    return host::host_checkpoint();
}

// Yield accumulation output hash (accumulate only)
fn void yield_hash(types::Hash* hash)
{
    host::host_yield((char*)hash);
}

// Create a new service (accumulate only)
fn types::ServiceId? new_service(
    types::Hash* code_hash,
    ulong code_len,
    types::Gas min_gas_acc,
    types::Gas min_gas_memo,
    ulong gratis_offset,
    types::ServiceId desired_id
)
{
    ulong ret = host::host_new(
        (char*)code_hash,
        code_len,
        min_gas_acc,
        min_gas_memo,
        gratis_offset,
        (ulong)desired_id
    );
    if (ret == types::HOST_HUH) return result::HOST_UNPRIVILEGED~;
    if (ret == types::HOST_CASH) return result::INSUFFICIENT_BALANCE~;
    if (ret == types::HOST_FULL) return result::HOST_ERROR~;
    return (types::ServiceId)ret;
}

// Upgrade service code (accumulate only)
fn void upgrade(types::Hash* code_hash, types::Gas min_gas_acc, types::Gas min_gas_memo)
{
    host::host_upgrade(
        (char*)code_hash,
        min_gas_acc,
        min_gas_memo
    );
}

// ---------------------------------------------------------------------------
// Fetch helpers — raw wrappers for all fetch modes.
// Context-appropriate methods are in refine.c3, accumulate.c3, entry_authorizer.c3.
// ---------------------------------------------------------------------------

// Mode 0: Get chain parameters
fn types::ChainParams? chain_params()
{
    types::ChainParams params;
    ulong ret = host::host_fetch(
        (char*)&params,
        0,
        types::ChainParams.sizeof,
        types::FETCH_CHAIN_PARAMS,
        0, 0
    );
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return params;
}

// Mode 1: Get 32-byte chain entropy
// Entropy η₀' (accumulate) or H₀ zero-hash (refine)
fn void? chain_entropy(char* out_32)
{
    ulong ret = host::host_fetch(
        out_32,
        0,
        32,
        types::FETCH_CHAIN_ENTROPY32,
        0, 0
    );
    if (ret == types::HOST_NONE) return result::NO_DATA~;
}

// Mode 2: Authorizer trace r (refine only)
fn usz? fetch_auth_trace(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_AUTH_TRACE, 0, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 3: Extrinsic segment by item index + segment index (refine only)
fn usz? fetch_extrinsic_segment(uint item_idx, uint seg_idx, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_EXTRINSIC_SEG, (ulong)item_idx, (ulong)seg_idx);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 4: Extrinsic segment for current work item (refine only)
fn usz? fetch_extrinsic_segment_current(uint seg_idx, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_EXTRINSIC_SEG_CUR, (ulong)seg_idx, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 5: Import segment by item index + segment index (refine only)
fn usz? fetch_import_segment(uint item_idx, uint seg_idx, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_IMPORT_SEG, (ulong)item_idx, (ulong)seg_idx);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 6: Import segment for current work item (refine only)
fn usz? fetch_import_segment_current(uint seg_idx, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_IMPORT_SEG_CUR, (ulong)seg_idx, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 7: Encoded work-package E(p) (refine + authorizer)
fn usz? fetch_work_package(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_WORK_PACKAGE, 0, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 8: Work-package authorization p_f (refine + authorizer)
fn usz? fetch_wp_authorization(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_WP_AUTH, 0, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 9: Work-package justification p_j (refine + authorizer)
fn usz? fetch_wp_justification(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_WP_JUSTIFICATION, 0, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 10: Encoded refinement context E(p_c) (refine + authorizer)
fn usz? fetch_refine_context(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_REFINE_CONTEXT, 0, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 11: All work-item summaries (refine + authorizer)
fn usz? fetch_item_summaries(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_ITEM_SUMMARIES, 0, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 12: Specific work-item summary by index (refine + authorizer)
fn usz? fetch_item_summary(uint index, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_ITEM_SUMMARY, (ulong)index, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 13: Work-item payload by index (refine + authorizer)
fn usz? fetch_nth_payload(uint index, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_NTH_ITEM_PAYLOAD, (ulong)index, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 14: All accumulate items encoded (accumulate only)
fn usz? fetch_inputs(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_INPUTS, 0, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// Mode 15: Single accumulate item by index (accumulate only)
fn usz? fetch_single_item(uint index, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(buf, 0, buf_len, types::FETCH_SINGLE_ITEM, (ulong)index, 0);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}
