// JAM SDK - Refine Context
// Typed context for refine entry points.
// Only operations valid during off-chain computation are exposed here.
// Accumulate-only operations (kv_write, transfer, checkpoint, etc.) are absent,
// so the compiler rejects their use inside refine.
//
// Context: refine-only
module jam::refine;

import jam::types;
import jam::service;
import jam::storage;
import jam::host;
import jam::result;
import jam::codec;

// Refine execution context. Passed by pointer to refine().
// Fields are private; access them through the methods below.
struct Ctx
{
    types::CoreIndex _core_index;
    uint             _work_item_index;
    types::ServiceId _service_id;
    char*            _work_payload;
    ulong            _work_payload_len;
    types::Hash      _work_package_hash;
}

// Sub-VM machine handle. Created via Ctx.create_machine(), valid for the
// lifetime of the refine execution. Must be destroyed with Machine.destroy().
struct Machine
{
    ulong _id;
}

// ---------------------------------------------------------------------------
// Context accessors
// ---------------------------------------------------------------------------

// Core index on which this work item is being refined.
fn types::CoreIndex Ctx.core_index(Ctx* self) { return self._core_index; }

// Zero-based work item index within the work package.
fn uint Ctx.work_item_index(Ctx* self) { return self._work_item_index; }

// Own service ID.
fn types::ServiceId Ctx.service_id(Ctx* self) { return self._service_id; }

// Pointer to work item payload bytes (zero-copy, may be null).
fn char* Ctx.payload(Ctx* self) { return self._work_payload; }

// Length of the work item payload in bytes.
fn ulong Ctx.payload_len(Ctx* self) { return self._work_payload_len; }

// Pointer to the 32-byte work package hash.
fn types::Hash* Ctx.work_package_hash(Ctx* self) { return &self._work_package_hash; }

// ---------------------------------------------------------------------------
// Chain queries (read-only). See service.c3 for full documentation.
// ---------------------------------------------------------------------------

fn types::Gas Ctx.gas(Ctx* self) { return service::gas_remaining(); }
fn types::ServiceInfo? Ctx.service_info(Ctx* self) { return service::service_info(); }
fn types::ServiceInfo? Ctx.service_info_of(Ctx* self, types::ServiceId id) { return service::service_info_of(id); }
fn types::Balance? Ctx.balance(Ctx* self) { return service::balance(); }

// Historical preimage lookup (offset 0). Faults: result::NO_DATA.
// For non-zero offset call host::host_historical_lookup() directly
// (6 args + self would exceed PolkaVM's a0-a5 register limit).
fn usz? Ctx.historical_lookup(Ctx* self, types::ServiceId svc_id, char* hash, char* out, usz max_len)
{
    ulong ret = host::host_historical_lookup(
        (ulong)svc_id, hash, out, 0, (ulong)max_len
    );
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// ---------------------------------------------------------------------------
// Work output
// ---------------------------------------------------------------------------

// Exports a data segment as work output (addressable by root hash after attestation).
// Returns segment index. Faults: result::NO_DATA.
fn ulong? Ctx.export_segment(Ctx* self, char* ptr, ulong len)
{
    ulong ret = host::host_export(ptr, len);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return ret;
}

// ---------------------------------------------------------------------------
// Fetch — data available in refine context (GP B.6)
// Modes: 0(params), 1(H₀), 2(auth trace), 3-6(segments), 7-13(work package)
// Modes 14-15 (accumulate items) return NONE in refine.
// ---------------------------------------------------------------------------

// Mode 0: Params
fn types::ChainParams? Ctx.chain_params(Ctx* self) { return service::chain_params(); }

// Mode 1: Entropy H₀ zero-hash
fn void? Ctx.chain_entropy(Ctx* self, char* out_32) { return service::chain_entropy(out_32); }

// Mode 2: Authorizer trace r
fn usz? Ctx.auth_trace(Ctx* self, char* buf, usz buf_len) { return service::fetch_auth_trace(buf, buf_len); }

// Mode 3: Extrinsic segment by item index + segment index
fn usz? Ctx.extrinsic_segment(Ctx* self, uint item_idx, uint seg_idx, char* buf, usz buf_len) {
    return service::fetch_extrinsic_segment(item_idx, seg_idx, buf, buf_len);
}

// Mode 4: Extrinsic segment for current work item
fn usz? Ctx.extrinsic_segment_current(Ctx* self, uint seg_idx, char* buf, usz buf_len) {
    return service::fetch_extrinsic_segment_current(seg_idx, buf, buf_len);
}

// Mode 5: Import segment by item index + segment index
fn usz? Ctx.import_segment(Ctx* self, uint item_idx, uint seg_idx, char* buf, usz buf_len) {
    return service::fetch_import_segment(item_idx, seg_idx, buf, buf_len);
}

// Mode 6: Import segment for current work item
fn usz? Ctx.import_segment_current(Ctx* self, uint seg_idx, char* buf, usz buf_len) {
    return service::fetch_import_segment_current(seg_idx, buf, buf_len);
}

// Mode 7: Encoded work-package E(p)
fn usz? Ctx.work_package(Ctx* self, char* buf, usz buf_len) { return service::fetch_work_package(buf, buf_len); }

// Mode 8: Work-package authorization p_f
fn usz? Ctx.wp_authorization(Ctx* self, char* buf, usz buf_len) { return service::fetch_wp_authorization(buf, buf_len); }

// Mode 9: Work-package justification p_j
fn usz? Ctx.wp_justification(Ctx* self, char* buf, usz buf_len) { return service::fetch_wp_justification(buf, buf_len); }

// Mode 10: Encoded refinement context E(p_c)
fn usz? Ctx.refine_context(Ctx* self, char* buf, usz buf_len) { return service::fetch_refine_context(buf, buf_len); }

// Mode 11: All work-item summaries
fn usz? Ctx.item_summaries(Ctx* self, char* buf, usz buf_len) { return service::fetch_item_summaries(buf, buf_len); }

// Mode 12: Specific work-item summary by index
fn usz? Ctx.item_summary(Ctx* self, uint index, char* buf, usz buf_len) { return service::fetch_item_summary(index, buf, buf_len); }

// Mode 13: Work-item payload by index
fn usz? Ctx.nth_payload(Ctx* self, uint index, char* buf, usz buf_len) { return service::fetch_nth_payload(index, buf, buf_len); }

// ---------------------------------------------------------------------------
// Sub-VM (Machine)
// ---------------------------------------------------------------------------

// Creates a sub-VM from PVM code. Faults: result::HOST_ERROR.
fn Machine? Ctx.create_machine(Ctx* self, char* code, ulong len, ulong pc)
{
    ulong id = host::host_machine(code, len, pc);
    if (id == types::HOST_NONE) return result::HOST_ERROR~;
    Machine m;
    m._id = id;
    return m;
}

// Reads bytes from sub-VM memory. Faults: result::HOST_ERROR.
fn void? Machine.read(Machine* self, char* out, ulong addr, ulong len)
{
    ulong ret = host::host_peek(self._id, out, addr, len);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
}

// Writes bytes into sub-VM memory. Faults: result::HOST_ERROR.
fn void? Machine.write(Machine* self, ulong addr, char* data, ulong len)
{
    ulong ret = host::host_poke(self._id, addr, data, len);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
}

// Sets sub-VM page permissions (mode: 0=none, 1=ro, 2=rw). Faults: result::HOST_ERROR.
fn void? Machine.set_pages(Machine* self, ulong start, ulong count, ulong mode)
{
    ulong ret = host::host_pages(self._id, start, count, mode);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
}

// Runs sub-VM until halt. params: 14×u64 register init block. Faults: result::HOST_ERROR.
fn ulong? Machine.invoke(Machine* self, char* params)
{
    ulong ret = host::host_invoke(self._id, params);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
    return ret;
}

// Destroys the sub-VM. Safe to call multiple times (idempotent).
fn void Machine.destroy(Machine* self)
{
    if (self._id == types::HOST_NONE) return;
    host::host_expunge(self._id);
    self._id = types::HOST_NONE;
}

// ---------------------------------------------------------------------------
// Result builders
// ---------------------------------------------------------------------------

// Builds a RefineResult with the given output bytes.
fn types::RefineResult Ctx.result_ok(Ctx* self, char* ptr, usz len) { return service::refine_ok(ptr, len); }

// Builds an empty RefineResult (null, 0).
fn types::RefineResult Ctx.result_empty(Ctx* self) { return service::refine_empty(); }
