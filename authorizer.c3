// JAM SDK - Authorizer Context
// Typed context for is_authorized entry points.
// Only read-only operations are available; the compiler enforces this at the type level.
//
// Context: authorizer-only
module jam::authorizer;

import jam::types;
import jam::service;
import jam::storage;
import jam::host;
import jam::result;

// Authorizer execution context. Passed by pointer to is_authorized().
// Fields are private; access them through the methods below.
struct Ctx
{
    ushort _core_index;
}

// Core index this authorizer is being evaluated for.
fn ushort Ctx.core_index(Ctx* self) { return self._core_index; }

// ---------------------------------------------------------------------------
// Chain queries (read-only). See service.c3 for full documentation.
// ---------------------------------------------------------------------------

fn types::Gas Ctx.gas(Ctx* self) { return service::gas_remaining(); }
fn types::ChainParams? Ctx.chain_params(Ctx* self) { return service::chain_params(); }
fn types::ServiceInfo? Ctx.service_info(Ctx* self) { return service::service_info(); }
fn types::ServiceInfo? Ctx.service_info_of(Ctx* self, types::ServiceId id) { return service::service_info_of(id); }
fn types::Balance? Ctx.balance(Ctx* self) { return service::balance(); }

fn usz? Ctx.kv_read(Ctx* self, char* key, usz key_len, char* out, usz max_len)
{
    return storage::kv_read(key, key_len, out, 0, max_len);
}

fn usz? Ctx.lookup(Ctx* self, char* hash, char* out, usz offset, usz max_len)
{
    ulong ret = host::host_lookup(hash, out, (ulong)offset, (ulong)max_len);
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}
