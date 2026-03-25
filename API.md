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

### Shared (all three contexts)

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.gas()` | `Gas` | — |
| `ctx.chain_params()` | `ChainParams?` | `NO_DATA` |
| `ctx.service_info()` | `ServiceInfo?` | `HOST_ERROR` |
| `ctx.service_info_of(id)` | `ServiceInfo?` | `HOST_ERROR` |
| `ctx.balance()` | `Balance?` | `HOST_ERROR` |

### refine::Ctx + accumulate::Ctx only

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.chain_entropy(out_32)` | `void?` | `NO_DATA` |
| `ctx.lookup(hash, out, offset, max_len)` | `usz?` | `NO_DATA` |

### refine::Ctx only

#### Accessors

| Method | Returns | Notes |
|--------|---------|-------|
| `ctx.core_index()` | `CoreIndex` | |
| `ctx.work_item_index()` | `uint` | |
| `ctx.service_id()` | `ServiceId` | |
| `ctx.payload()` | `char*` | zero-copy |
| `ctx.payload_len()` | `ulong` | |
| `ctx.work_package_hash()` | `Hash*` | |

#### Historical lookup

| Method | Returns | Faults | Notes |
|--------|---------|--------|-------|
| `ctx.historical_lookup(svc_id, hash, out, max_len)` | `usz?` | `NO_DATA` | offset=0 only |

#### Fetch (GP B.6 — modes 0-13 available)

| Method | Mode | Returns | Faults |
|--------|------|---------|--------|
| `ctx.auth_trace(buf, buf_len)` | 2 | `usz?` | `NO_DATA` |
| `ctx.extrinsic_segment(item_idx, seg_idx, buf, buf_len)` | 3 | `usz?` | `NO_DATA` |
| `ctx.extrinsic_segment_current(seg_idx, buf, buf_len)` | 4 | `usz?` | `NO_DATA` |
| `ctx.import_segment(item_idx, seg_idx, buf, buf_len)` | 5 | `usz?` | `NO_DATA` |
| `ctx.import_segment_current(seg_idx, buf, buf_len)` | 6 | `usz?` | `NO_DATA` |
| `ctx.work_package(buf, buf_len)` | 7 | `usz?` | `NO_DATA` |
| `ctx.wp_authorization(buf, buf_len)` | 8 | `usz?` | `NO_DATA` |
| `ctx.wp_justification(buf, buf_len)` | 9 | `usz?` | `NO_DATA` |
| `ctx.refine_context(buf, buf_len)` | 10 | `usz?` | `NO_DATA` |
| `ctx.item_summaries(buf, buf_len)` | 11 | `usz?` | `NO_DATA` |
| `ctx.item_summary(index, buf, buf_len)` | 12 | `usz?` | `NO_DATA` |
| `ctx.nth_payload(index, buf, buf_len)` | 13 | `usz?` | `NO_DATA` |

#### Export + sub-VM

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.export_segment(ptr, len)` | `ulong?` | `NO_DATA` |
| `ctx.create_machine(code, len, pc)` | `Machine?` | `HOST_ERROR` |
| `ctx.result_ok(ptr, len)` | `RefineResult` | — |
| `ctx.result_empty()` | `RefineResult` | — |

#### Machine (sub-VM, refine only)

| Method | Returns | Faults |
|--------|---------|--------|
| `m.read(out, addr, len)` | `void?` | `HOST_ERROR` |
| `m.write(addr, data, len)` | `void?` | `HOST_ERROR` |
| `m.set_pages(start, count, mode)` | `void?` | `HOST_ERROR` |
| `m.invoke(params)` | `ulong?` | `HOST_ERROR` |
| `m.destroy()` | `void` | — idempotent |

### accumulate::Ctx only

#### Accessors

| Method | Returns |
|--------|---------|
| `ctx.timeslot()` | `Timeslot` |
| `ctx.service_id()` | `ServiceId` |
| `ctx.num_inputs()` | `Gas` |

#### Fetch (GP eq 3943 — modes 0, 1, 14, 15 available)

| Method | Mode | Returns | Faults |
|--------|------|---------|--------|
| `ctx.entropy(buf, buf_len)` | 1 | `usz?` | `NO_DATA` |
| `ctx.fetch_items(buf, buf_len)` | 14 | `usz?` | `NO_DATA` |
| `ctx.fetch_item(index, buf, buf_len)` | 15 | `usz?` | `NO_DATA` |

#### Input iteration

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.inputs()` | `InputIter` | — lazy fetch |
| `iter.next()` | `AccumulateInput?` | `NO_DATA`, `UNDECODABLE` |

#### Storage

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.kv_read(key, key_len, out, max_len)` | `usz?` | `NO_KEY` |
| `ctx.kv_write(key, key_len, value, value_len)` | `void?` | `INSUFFICIENT_BALANCE` |
| `ctx.kv_delete(key, key_len)` | `void?` | `INSUFFICIENT_BALANCE` |

#### State mutations

| Method | Returns | Faults |
|--------|---------|--------|
| `ctx.checkpoint()` | `Gas` | — |
| `ctx.yield_hash(hash)` | `void` | — |
| `ctx.transfer(receiver, amount, gas_limit, memo)` | `void?` | `UNREACHABLE`, `INSUFFICIENT_BALANCE`, `HOST_ERROR` |
| `ctx.new_service(code_hash, code_len, min_gas_acc, min_gas_memo)` | `ServiceId?` | `INSUFFICIENT_BALANCE`, `HOST_ERROR` |
| `ctx.upgrade(code_hash, min_gas_acc, min_gas_memo)` | `void` | — (panics) |
| `ctx.eject(service_id, memo)` | `void?` | `UNREACHABLE`, `HOST_ERROR` |
| `ctx.solicit(hash, len)` | `void?` | `HOST_ERROR` |
| `ctx.forget(hash, len)` | `void?` | `HOST_ERROR` |
| `ctx.query(hash, len)` | `ulong?` | `NO_DATA` |
| `ctx.provide(service_id, data, len)` | `void?` | `HOST_ERROR` |
| `ctx.assign(core, authorizers, assigner)` | `void?` | `HOST_UNPRIVILEGED`, `HOST_ERROR` |
| `ctx.designate(validators)` | `void?` | `HOST_UNPRIVILEGED` |

### authorizer::Ctx only

#### Accessors

| Method | Returns |
|--------|---------|
| `ctx.core_index()` | `ushort` |

#### Fetch (GP B.2 — modes 0, 7-13 available)

| Method | Mode | Returns | Faults |
|--------|------|---------|--------|
| `ctx.work_package(buf, buf_len)` | 7 | `usz?` | `NO_DATA` |
| `ctx.wp_authorization(buf, buf_len)` | 8 | `usz?` | `NO_DATA` |
| `ctx.wp_justification(buf, buf_len)` | 9 | `usz?` | `NO_DATA` |
| `ctx.refine_context(buf, buf_len)` | 10 | `usz?` | `NO_DATA` |
| `ctx.item_summaries(buf, buf_len)` | 11 | `usz?` | `NO_DATA` |
| `ctx.item_summary(index, buf, buf_len)` | 12 | `usz?` | `NO_DATA` |
| `ctx.nth_payload(index, buf, buf_len)` | 13 | `usz?` | `NO_DATA` |

---

## Fetch discriminators (`jam::types`)

| Constant | Mode | Description | Authorizer | Refine | Accumulate |
|----------|------|-------------|:----------:|:------:|:----------:|
| `FETCH_CHAIN_PARAMS` | 0 | Protocol configuration | ✓ | ✓ | ✓ |
| `FETCH_CHAIN_ENTROPY32` | 1 | Entropy η₀' / H₀ | — | ✓ | ✓ |
| `FETCH_AUTH_TRACE` | 2 | Authorizer trace r | — | ✓ | — |
| `FETCH_EXTRINSIC_SEG` | 3 | Extrinsic segment x̄[i][j] | — | ✓ | — |
| `FETCH_EXTRINSIC_SEG_CUR` | 4 | Extrinsic segment current | — | ✓ | — |
| `FETCH_IMPORT_SEG` | 5 | Import segment ī[i][j] | — | ✓ | — |
| `FETCH_IMPORT_SEG_CUR` | 6 | Import segment current | — | ✓ | — |
| `FETCH_WORK_PACKAGE` | 7 | Encoded work-package E(p) | ✓ | ✓ | — |
| `FETCH_WP_AUTH` | 8 | WP authorization p_f | ✓ | ✓ | — |
| `FETCH_WP_JUSTIFICATION` | 9 | WP justification p_j | ✓ | ✓ | — |
| `FETCH_REFINE_CONTEXT` | 10 | Refinement context E(p_c) | ✓ | ✓ | — |
| `FETCH_ITEM_SUMMARIES` | 11 | All work-item summaries | ✓ | ✓ | — |
| `FETCH_ITEM_SUMMARY` | 12 | Work-item summary [i] | ✓ | ✓ | — |
| `FETCH_NTH_ITEM_PAYLOAD` | 13 | Work-item payload [i] | ✓ | ✓ | — |
| `FETCH_INPUTS` | 14 | All accumulate items | — | — | ✓ |
| `FETCH_SINGLE_ITEM` | 15 | Single accumulate item [i] | — | — | ✓ |

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
