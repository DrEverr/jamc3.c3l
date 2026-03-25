// JAM SDK - Accumulate Context
// Typed context for accumulate entry points.
// Exposes the full set of on-chain mutation operations that are only valid
// inside accumulate. Refine-only operations (export_segment, create_machine,
// historical_lookup, etc.) are absent, so the compiler rejects their use.
//
// Context: accumulate-only
module jam::accumulate;

import jam::types;
import jam::service;
import jam::storage;
import jam::host;
import jam::result;
import jam::codec;
import jam::log;

// Accumulate execution context. Passed by pointer to accumulate().
// Fields are private; access them through the methods below.
//
// The _inputs_buf pointer references a 65 536-byte buffer allocated on the
// stack frame of jam_entry_accumulate in entry.c3. This buffer remains live
// for the entire accumulate invocation, enabling zero-copy input iteration.
struct Ctx
{
    types::Timeslot  _timeslot;
    types::ServiceId _service_id;
    ulong            _num_inputs;
    char*            _inputs_buf;      // pointer to 65 536-byte buffer in entry.c3
    usz              _inputs_len;
    bool             _inputs_fetched;
}

// Iterator over accumulate inputs (operands and transfers).
// Zero-copy: data pointers inside WorkDigestOutput reference directly into
// the 65 536-byte buffer owned by the Ctx's entry.c3 stack frame.
struct InputIter
{
    codec::DecodeCtx _dec;       // cursor into the inputs buffer, positioned after the count varint
    ulong            _remaining; // number of items not yet consumed
}

// ---------------------------------------------------------------------------
// Context accessors
// ---------------------------------------------------------------------------

// Current chain timeslot.
fn types::Timeslot Ctx.timeslot(Ctx* self) { return self._timeslot; }

// Own service ID.
fn types::ServiceId Ctx.service_id(Ctx* self) { return self._service_id; }

// Total number of inputs (operands + transfers) in this accumulate round.
fn ulong Ctx.num_inputs(Ctx* self) { return self._num_inputs; }

// ---------------------------------------------------------------------------
// Chain queries (read-only). See service.c3 for full documentation.
// ---------------------------------------------------------------------------

fn types::Gas Ctx.gas(Ctx* self) { return service::gas_remaining(); }
fn types::ServiceInfo? Ctx.service_info(Ctx* self) { return service::service_info(); }
fn types::ServiceInfo? Ctx.service_info_of(Ctx* self, types::ServiceId id) { return service::service_info_of(id); }
fn types::Balance? Ctx.balance(Ctx* self) { return service::balance(); }

fn usz? Ctx.lookup(Ctx* self, char* hash, char* out, usz offset, usz max_len)
{
    ulong ret = host::host_lookup(hash, out, (ulong)offset, (ulong)max_len);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// ---------------------------------------------------------------------------
// Fetch — data available in accumulate context (GP eq 3943)
// Modes: 0(params), 1(entropy η₀'), 14(all items), 15(single item)
// Modes 2-13 (refine/authorizer only) return NONE in accumulate.
// ---------------------------------------------------------------------------

// Mode 0: Params
fn types::ChainParams? Ctx.chain_params(Ctx* self) { return service::chain_params(); }

// Mode 1: Entropy η₀' (32 bytes)
fn void? Ctx.chain_entropy(Ctx* self, char* out_32) { return service::chain_entropy(out_32); }

// Mode 14: All accumualte items
fn usz? Ctx.fetch_items(Ctx* self, uint index, char* buf, usz buf_len) {
  return service::fetch_inputs(buf, buf_len);
}

// Mode 15: Single accumulate item by index
fn usz? Ctx.fetch_item(Ctx* self, uint index, char* buf, usz buf_len) {
    return service::fetch_single_item(index, buf, buf_len);
}

// ---------------------------------------------------------------------------
// Storage. For non-zero offset or cross-service read use storage::kv_read() / kv_read_of().
// ---------------------------------------------------------------------------

// Read from own KV storage (offset 0). Faults: result::NO_KEY.
fn usz? Ctx.kv_read(Ctx* self, char* key, usz key_len, char* out, usz max_len)
{
    return storage::kv_read(key, key_len, out, 0, max_len);
}

// Write to own KV storage. Faults: result::INSUFFICIENT_BALANCE.
fn void? Ctx.kv_write(Ctx* self, char* key, usz key_len, char* value, usz value_len)
{
    storage::kv_write(key, key_len, value, value_len)!;
}

// Delete key from own KV storage. Faults: result::INSUFFICIENT_BALANCE.
fn void? Ctx.kv_delete(Ctx* self, char* key, usz key_len)
{
    return storage::kv_delete(key, key_len);
}

// ---------------------------------------------------------------------------
// Input iteration
// ---------------------------------------------------------------------------

// Returns an iterator over the accumulate inputs (lazy: the host fetch is
// deferred until the first call to this method).
//
// Returns:
//   InputIter positioned at the first input.
//
// Context: accumulate-only
fn InputIter Ctx.inputs(Ctx* self)
{
    if (!self._inputs_fetched)
    {
        usz? maybe_len = service::fetch_inputs(self._inputs_buf, 65536);
        self._inputs_len = maybe_len ?? 0;
        self._inputs_fetched = true;
        if (self._inputs_len == 65536)
        {
            log::warn("JAM", "inputs may be truncated: buffer full (65536 bytes)");
        }
    }

    codec::DecodeCtx dec = codec::decode_ctx_init(self._inputs_buf, (ulong)self._inputs_len);
    ulong count = codec::decode_natural_num(&dec) ?? 0;

    InputIter iter;
    iter._dec       = dec;
    iter._remaining = count;
    return iter;
}

// Returns the next input from the iterator.
//
// Decodes the binary wire format emitted by the JAM protocol:
//   disc=0x00 (OPERAND): 4×hash(128B) || varint(gas) || status(1B) [|| varint(len) || data]
//   disc=0x01 (TRANSFER): sender(u32) || receiver(u32) || amount(u64) || memo(128B) || gas(u64)
//
// Data pointers inside WorkDigestOutput are zero-copy references into the
// 65 536-byte buffer on the entry.c3 stack frame.
//
// Returns:
//   The next AccumulateInput on success.
//
// Errors:
//   result::NO_DATA    - no more inputs remain.
//   result::UNDECODABLE - wire format is malformed.
//
// Context: accumulate-only
fn types::AccumulateInput? InputIter.next(InputIter* self)
{
    if (self._remaining == 0) return result::NO_DATA~;

    char? disc_r = codec::decode_u8(&self._dec);
    if (catch disc_r) return result::UNDECODABLE~;
    char disc = disc_r;

    types::AccumulateInput input;

    if (disc == 0x01)
    {
        // --- TRANSFER ---
        input.kind = types::AccumulateInputKind.TRANSFER;

        uint? sender = codec::decode_u32(&self._dec);
        if (catch sender) return result::UNDECODABLE~;

        uint? receiver = codec::decode_u32(&self._dec);
        if (catch receiver) return result::UNDECODABLE~;

        ulong? amount = codec::decode_u64(&self._dec);
        if (catch amount) return result::UNDECODABLE~;

        if (catch codec::decode_fixed(&self._dec, (char*)&input.transfer.memo, 128))
        {
            return result::UNDECODABLE~;
        }

        ulong? gas_limit = codec::decode_u64(&self._dec);
        if (catch gas_limit) return result::UNDECODABLE~;

        input.transfer.sender    = (types::ServiceId)sender;
        input.transfer.receiver  = (types::ServiceId)receiver;
        input.transfer.amount    = amount;
        input.transfer.gas_limit = gas_limit;

        self._remaining--;
        return input;
    }
    else if (disc == 0x00)
    {
        // --- OPERAND ---
        input.kind = types::AccumulateInputKind.OPERAND;

        // Four 32-byte hashes
        if (catch codec::decode_fixed(&self._dec, (char*)&input.operand.work_package_hash, 32))
        {
            return result::UNDECODABLE~;
        }
        if (catch codec::decode_fixed(&self._dec, (char*)&input.operand.segment_root, 32))
        {
            return result::UNDECODABLE~;
        }
        if (catch codec::decode_fixed(&self._dec, (char*)&input.operand.authorizer_hash, 32))
        {
            return result::UNDECODABLE~;
        }
        if (catch codec::decode_fixed(&self._dec, (char*)&input.operand.payload_hash, 32))
        {
            return result::UNDECODABLE~;
        }

        // Accumulate gas limit (variable-length natural number)
        ulong? gas = codec::decode_natural_num(&self._dec);
        if (catch gas) return result::UNDECODABLE~;
        input.operand.gas_limit = gas;

        // Digest output: status byte + optional data
        char? status_r = codec::decode_u8(&self._dec);
        if (catch status_r) return result::UNDECODABLE~;

        input.operand.digest_output.status   = (types::WorkDigestStatus)status_r;
        input.operand.digest_output.data     = null;
        input.operand.digest_output.data_len = 0;

        // Initialise work_report_output to empty
        input.operand.work_report_output.status   = types::WorkDigestStatus.OK;
        input.operand.work_report_output.data     = null;
        input.operand.work_report_output.data_len = 0;

        if (status_r == (char)0) // WorkDigestStatus.OK == 0
        {
            // Success: varint(data_len) + data bytes (zero-copy pointer)
            ulong? dlen = codec::decode_natural_num(&self._dec);
            if (catch dlen) return result::UNDECODABLE~;

            if (self._dec.remaining < dlen) return result::UNDECODABLE~;

            input.operand.digest_output.data     = self._dec.ptr;
            input.operand.digest_output.data_len = dlen;
            self._dec.ptr       += dlen;
            self._dec.remaining -= dlen;
        }

        self._remaining--;
        return input;
    }
    else
    {
        return result::UNDECODABLE~;
    }
}

// ---------------------------------------------------------------------------
// State mutations (accumulate-only host calls)
// ---------------------------------------------------------------------------

// Commits storage writes since last checkpoint. Returns gas consumed.
fn types::Gas Ctx.checkpoint(Ctx* self) { return service::checkpoint(); }

// Sets the accumulation output hash (the "yield" value).
fn void Ctx.yield_hash(Ctx* self, types::Hash* hash) { service::yield_hash(hash); }

// Transfer tokens. Faults: result::UNREACHABLE, INSUFFICIENT_BALANCE, HOST_ERROR.
fn void? Ctx.transfer(Ctx* self, types::ServiceId receiver, types::Balance amount, types::Gas gas_limit, types::Memo* memo)
{
    return service::transfer(receiver, amount, gas_limit, memo);
}

// Creates a new service (auto-assigned ID, no gratis storage).
// For privileged options (gratis_offset, desired_id) call service::new_service() directly.
// Faults: result::INSUFFICIENT_BALANCE, HOST_ERROR.
fn types::ServiceId? Ctx.new_service(Ctx* self,
    types::Hash* code_hash,
    ulong        code_len,
    types::Gas   min_gas_acc,
    types::Gas   min_gas_memo)
{
    return service::new_service(code_hash, code_len, min_gas_acc, min_gas_memo, 0, 65536);
}

// Upgrades service code. Panics on failure (no error return per GP spec).
fn void Ctx.upgrade(Ctx* self, types::Hash* code_hash, types::Gas min_gas_acc, types::Gas min_gas_memo)
{
    service::upgrade(code_hash, min_gas_acc, min_gas_memo);
}

// Ejects (destroys) a service account. Faults: result::UNREACHABLE, HOST_ERROR.
fn void? Ctx.eject(Ctx* self, types::ServiceId service_id, types::Memo* memo)
{
    ulong ret = host::host_eject((ulong)service_id, (char*)memo);
    if (ret == types::HOST_WHO)  return result::UNREACHABLE~;
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
}

// Solicits a preimage by hash. Faults: result::HOST_ERROR.
fn void? Ctx.solicit(Ctx* self, char* hash, ulong len)
{
    ulong ret = host::host_solicit(hash, len);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
}

// Cancels a preimage solicitation. Faults: result::HOST_ERROR.
fn void? Ctx.forget(Ctx* self, char* hash, ulong len)
{
    ulong ret = host::host_forget(hash, len);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
}

// Queries preimage status (0=not solicited, 1=pending, 2=available). Faults: result::NO_DATA.
fn ulong? Ctx.query(Ctx* self, char* hash, ulong len)
{
    ulong ret = host::host_query(hash, len);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return ret;
}

// Provides preimage data to a soliciting service. Faults: result::HOST_ERROR.
fn void? Ctx.provide(Ctx* self, types::ServiceId service_id, char* data, ulong len)
{
    ulong ret = host::host_provide((ulong)service_id, data, len);
    if (ret == types::HOST_NONE) return result::HOST_ERROR~;
}

// bless() exceeds PolkaVM's 6-register limit as a Ctx method.
// Call host::host_bless(manager, assigners, delegator, registrar, extra, count) directly.

// Assigns authorizer pool to a core. Faults: result::HOST_UNPRIVILEGED, HOST_ERROR.
fn void? Ctx.assign(Ctx* self, types::CoreIndex core, char* authorizers, types::ServiceId assigner)
{
    ulong ret = host::host_assign((ulong)core, authorizers, (ulong)assigner);
    if (ret == types::HOST_HUH)  return result::HOST_UNPRIVILEGED~;
    if (ret == types::HOST_CORE) return result::HOST_ERROR~;
}

// Registers pending validator keys (registrar-only). Faults: result::HOST_UNPRIVILEGED.
fn void? Ctx.designate(Ctx* self, char* validators)
{
    ulong ret = host::host_designate(validators);
    if (ret == types::HOST_HUH) return result::HOST_UNPRIVILEGED~;
}
