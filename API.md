# jamc3 — API Reference

## Entry points

The user implements these hooks; the SDK calls them:

| Hook | Signature | File |
|------|-----------|------|
| `refine` | `fn RefineResult refine(refine::Ctx* ctx)` | entry.c3 |
| `accumulate` | `fn void accumulate(accumulate::Ctx* ctx)` | entry.c3 |
| `is_authorized` | `fn void is_authorized(authorizer::Ctx* ctx)` | entry_authorizer.c3 |

---

## Methods by context

**Legend:** `?` = returns optional (faults on error). Fault types in parentheses.

### Shared (all three contexts) — defined per-context, delegating to `service.c3`

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.gas()` | `Gas` | — |
| `ctx.chain_params()` | `ChainParams?` | `NO_DATA` |
| `ctx.service_info()` | `ServiceInfo?` | `HOST_ERROR` |
| `ctx.service_info_of(id)` | `ServiceInfo?` | `HOST_ERROR` |
| `ctx.balance()` | `Balance?` | `HOST_ERROR` |
| `ctx.lookup(hash, out, offset, max_len)` | `usz?` | `NO_DATA` |
| `ctx.kv_read(key, key_len, out, max_len)` | `usz?` | `NO_KEY` |

### refine::Ctx + accumulate::Ctx only

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.chain_entropy(out_32)` | `void?` | `NO_DATA` |

### refine::Ctx only

| Method | Returns | Faults | Notes |
|--------|---------|--------|-------|
| `ctx.core_index()` | `CoreIndex` | — | |
| `ctx.work_item_index()` | `uint` | — | |
| `ctx.service_id()` | `ServiceId` | — | |
| `ctx.payload()` | `char*` | — | zero-copy |
| `ctx.payload_len()` | `ulong` | — | |
| `ctx.work_package_hash()` | `Hash*` | — | |
| `ctx.historical_lookup(svc_id, hash, out, max_len)` | `usz?` | `NO_DATA` | offset=0 only |
| `ctx.export_segment(ptr, len)` | `ulong?` | `NO_DATA` | |
| `ctx.create_machine(code, len, pc)` | `Machine?` | `HOST_ERROR` | |
| `ctx.result_ok(ptr, len)` | `RefineResult` | — | |
| `ctx.result_empty()` | `RefineResult` | — | |

#### Machine (sub-VM, refine only)

| Method | Returns | Faults |
|--------|---------|--------|
| `m.read(out, addr, len)` | `void?` | `HOST_ERROR` |
| `m.write(addr, data, len)` | `void?` | `HOST_ERROR` |
| `m.set_pages(start, count, mode)` | `void?` | `HOST_ERROR` |
| `m.invoke(params)` | `ulong?` | `HOST_ERROR` |
| `m.destroy()` | `void` | — idempotent |

### accumulate::Ctx only

| Method | Returns | Faults | Notes |
|--------|---------|--------|-------|
| `ctx.timeslot()` | `Timeslot` | — | |
| `ctx.service_id()` | `ServiceId` | — | |
| `ctx.num_inputs()` | `Gas` | — | |
| `ctx.inputs()` | `InputIter` | — | lazy fetch |
| `ctx.kv_write(key, key_len, value, value_len)` | `void?` | `INSUFFICIENT_BALANCE` | |
| `ctx.kv_delete(key, key_len)` | `void?` | `INSUFFICIENT_BALANCE` | |
| `ctx.checkpoint()` | `Gas` | — | |
| `ctx.yield_hash(hash)` | `void` | — | |
| `ctx.transfer(receiver, amount, gas_limit, memo)` | `void?` | `UNREACHABLE`, `INSUFFICIENT_BALANCE`, `HOST_ERROR` | |
| `ctx.new_service(code_hash, code_len, min_gas_acc, min_gas_memo)` | `ServiceId?` | `INSUFFICIENT_BALANCE`, `HOST_ERROR` | |
| `ctx.upgrade(code_hash, min_gas_acc, min_gas_memo)` | `void` | — (panics) | |
| `ctx.eject(service_id, memo)` | `void?` | `UNREACHABLE`, `HOST_ERROR` | |
| `ctx.solicit(hash, len)` | `void?` | `HOST_ERROR` | |
| `ctx.forget(hash, len)` | `void?` | `HOST_ERROR` | |
| `ctx.query(hash, len)` | `ulong?` | `NO_DATA` | |
| `ctx.provide(service_id, data, len)` | `void?` | `HOST_ERROR` | |
| `ctx.assign(core, authorizers, assigner)` | `void?` | `HOST_UNPRIVILEGED`, `HOST_ERROR` | |
| `ctx.designate(validators)` | `void?` | `HOST_UNPRIVILEGED` | |

#### InputIter

| Method | Returns | Faults |
|--------|---------|--------|
| `iter.next()` | `AccumulateInput?` | `NO_DATA`, `UNDECODABLE` |

### authorizer::Ctx only

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.core_index()` | `ushort` | — |

*(Plus all shared methods above.)*

---

## Direct-call APIs (not on Ctx)

When PolkaVM's 6-register limit prevents a Ctx method, use these directly:

| Function | Module | Notes |
|----------|--------|-------|
| `storage::kv_read_of(id, key, key_len, out, offset, max_len)` | storage.c3 | cross-service read |
| `service::new_service(code_hash, code_len, min_gas_acc, min_gas_memo, gratis_offset, desired_id)` | service.c3 | privileged create |
| `host::host_bless(manager, assigners, delegator, registrar, extra, count)` | host.c3 | manager-only |
| `host::host_historical_lookup(svc_id, hash, out, offset, max_len)` | host.c3 | with offset |

---

## Fault types (`jam::result`)

| Fault | Meaning |
|-------|---------|
| `NO_KEY` | Key not found in storage |
| `NO_DATA` | Data unavailable (chain params, entropy, preimage, inputs exhausted) |
| `UNDECODABLE` | Wire format decode failure |
| `TOO_BIG` | Encode buffer too small |
| `INSUFFICIENT_BALANCE` | Not enough balance for operation |
| `UNREACHABLE` | Target service does not exist |
| `HOST_ERROR` | General host-call failure |
| `HOST_UNPRIVILEGED` | Caller lacks required privilege |
| `ALLOC_FAILURE` | Allocation failed |
