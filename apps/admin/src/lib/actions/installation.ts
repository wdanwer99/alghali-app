'use server';

import { requireAdmin } from '@/lib/auth';
import { done, fail, UUID } from './result';

const reason = (s: string | undefined) => (s ?? '').trim().slice(0, 500);

// ----------------------------------------------------------------- technicians

export async function setTechnicianStatus(
  technicianId: string,
  status: 'APPROVED' | 'REJECTED' | 'SUSPENDED',
  why?: string,
) {
  if (!UUID.test(technicianId)) return fail('INVALID_VALUE');
  if (status !== 'APPROVED' && !reason(why)) return fail('REASON_REQUIRED');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_set_technician_status', {
    p_technician_id: technicianId,
    p_status: status,
    p_reason: reason(why) || undefined,
  });
  return done(error);
}

// -------------------------------------------------------------------- bookings

export async function cancelBooking(bookingId: string, why: string) {
  if (!UUID.test(bookingId)) return fail('INVALID_VALUE');
  if (!reason(why)) return fail('REASON_REQUIRED');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_cancel_booking', {
    p_booking_id: bookingId,
    p_reason: reason(why),
  });
  return done(error);
}

/** Moves the job to the next free technician for the same time, or to "needs a new time". */
export async function reassignBooking(bookingId: string, why?: string) {
  if (!UUID.test(bookingId)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_reassign_booking', {
    p_booking_id: bookingId,
    p_reason: reason(why) || undefined,
  });
  return done(error);
}

/** For a job in progress whose code locked after five wrong tries (D-028). */
export async function completeBooking(bookingId: string) {
  if (!UUID.test(bookingId)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_complete_booking', { p_booking_id: bookingId });
  return done(error);
}

// -------------------------------------------------------------------- disputes

export async function replyDispute(disputeId: string, body: string) {
  if (!UUID.test(disputeId)) return fail('INVALID_VALUE');
  const text = (body ?? '').trim().slice(0, 2000);
  if (!text) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('dispute_reply', { p_dispute_id: disputeId, p_body: text });
  return done(error);
}

export async function updateDispute(
  disputeId: string,
  status: 'IN_REVIEW' | 'RESOLVED' | 'REJECTED',
  resolution?: string,
) {
  if (!UUID.test(disputeId) || !['IN_REVIEW', 'RESOLVED', 'REJECTED'].includes(status)) {
    return fail('INVALID_VALUE');
  }
  if (status !== 'IN_REVIEW' && !reason(resolution)) return fail('REASON_REQUIRED');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_update_dispute', {
    p_dispute_id: disputeId,
    p_status: status,
    p_resolution: reason(resolution) || undefined,
  });
  return done(error);
}
