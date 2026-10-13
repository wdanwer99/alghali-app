'use server';

import { requireAdmin } from '@/lib/auth';
import { done, fail, UUID } from './result';

const TXN = /^\d{6,20}$/;
const digitsOnly = (s: string | undefined) =>
  (s ?? '').replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/[\s-]/g, '');
const reason = (s: string | undefined) => (s ?? '').trim().slice(0, 500);

// ------------------------------------------------------------------- payments

/** After finding the transfer on the Bankak statement (D-054). */
export async function confirmPayment(
  paymentId: string,
  txn: string | undefined,
  refInNote: boolean,
) {
  const clean = digitsOnly(txn);
  if (!UUID.test(paymentId) || (clean && !TXN.test(clean))) return fail('INVALID_TXN');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_confirm_payment', {
    p_payment_id: paymentId,
    p_txn_no: clean || undefined,
    p_ref_in_note: refInNote,
  });
  return done(error);
}

const REJECT_REASONS = [
  'AMOUNT_WRONG',
  'NOT_ON_STATEMENT',
  'DUPLICATE',
  'UNREADABLE',
  'OTHER',
] as const;
export type RejectReason = (typeof REJECT_REASONS)[number];

export async function rejectPayment(paymentId: string, code: RejectReason, note?: string) {
  if (!UUID.test(paymentId) || !REJECT_REASONS.includes(code)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_reject_payment', {
    p_payment_id: paymentId,
    p_reason: code,
    p_note: reason(note) || undefined,
  });
  return done(error);
}

export async function markRefundPaid(refundId: string, txn: string) {
  const clean = digitsOnly(txn);
  if (!UUID.test(refundId) || !TXN.test(clean)) return fail('INVALID_TXN');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_mark_refund_paid', {
    p_refund_id: refundId,
    p_txn_no: clean,
  });
  return done(error);
}

// --------------------------------------------------------------------- orders

export async function cancelSubOrder(subOrderId: string, why: string) {
  if (!UUID.test(subOrderId)) return fail('INVALID_VALUE');
  if (!reason(why)) return fail('REASON_REQUIRED');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_cancel_suborder', {
    p_sub_order_id: subOrderId,
    p_reason: reason(why),
  });
  return done(error);
}

export async function completeSubOrder(subOrderId: string) {
  if (!UUID.test(subOrderId)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_complete_suborder', { p_sub_order_id: subOrderId });
  return done(error);
}

/** Approving refunds the buyer in full; declining needs a reason (D-085). */
export async function decideReturn(subOrderId: string, approve: boolean, note?: string) {
  if (!UUID.test(subOrderId)) return fail('INVALID_VALUE');
  if (!approve && !reason(note)) return fail('REASON_REQUIRED');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_decide_return', {
    p_sub_order_id: subOrderId,
    p_approve: approve,
    p_note: reason(note) || undefined,
  });
  return done(error);
}

// -------------------------------------------------------------------- payouts

export async function generatePayouts() {
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_generate_payouts', {});
  return done(error);
}

export async function approvePayouts(ids: string[]) {
  if (
    !Array.isArray(ids) ||
    ids.length === 0 ||
    ids.length > 500 ||
    !ids.every((id) => UUID.test(id))
  ) {
    return fail('INVALID_VALUE');
  }
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_approve_payouts', { p_ids: ids });
  return done(error);
}

export async function markPayoutPaid(payoutId: string, txn: string) {
  const clean = digitsOnly(txn);
  if (!UUID.test(payoutId) || !TXN.test(clean)) return fail('INVALID_TXN');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_mark_payout_paid', {
    p_payout_id: payoutId,
    p_txn_no: clean,
  });
  return done(error);
}

export async function cancelPayout(payoutId: string, why: string) {
  if (!UUID.test(payoutId)) return fail('INVALID_VALUE');
  if (!reason(why)) return fail('REASON_REQUIRED');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_cancel_payout', {
    p_payout_id: payoutId,
    p_reason: reason(why),
  });
  return done(error);
}
