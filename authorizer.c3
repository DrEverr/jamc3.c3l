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
fn types::ServiceInfo? Ctx.service_info(Ctx* self) { return service::service_info(); }
fn types::ServiceInfo? Ctx.service_info_of(Ctx* self, types::ServiceId id) { return service::service_info_of(id); }
fn types::Balance? Ctx.balance(Ctx* self) { return service::balance(); }

// ---------------------------------------------------------------------------
// Fetch — data available in authorizer context (GP B.2)
// Modes: 0(params), 7-13(work package info)
// All other modes return NONE (r=∅, x̄=∅, ī=∅, n=∅, i=∅).
// ---------------------------------------------------------------------------

// Mode 0: Params
fn types::ChainParams? Ctx.chain_params(Ctx* self) { return service::chain_params(); }

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
