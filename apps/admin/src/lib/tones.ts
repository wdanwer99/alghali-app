import type { Tone } from '@/components/admin/ui';
import type { PayoutStatus, PayStatus, SubStatus } from '@/lib/data/commerce';
import type { BookingStatus, DisputeStatus } from '@/lib/data/installation';

/** "PAYMENT_REVIEW" → "paymentReview", the dictionary's key for a database status. */
export function statusKey<T extends string>(status: T): CamelCase<T> {
  return status
    .toLowerCase()
    .replace(/_([a-z])/g, (_, c: string) => c.toUpperCase()) as CamelCase<T>;
}

type CamelCase<S extends string> = S extends `${infer A}_${infer B}`
  ? `${Lowercase<A>}${Capitalize<CamelCase<B>>}`
  : Lowercase<S>;

/** Status colours match the phone apps; the brand red is never used for a status. */
export const orderTone: Record<SubStatus, Tone> = {
  PENDING_PAYMENT: 'warning',
  PAYMENT_REVIEW: 'warning',
  CONFIRMED: 'info',
  READY: 'success',
  PICKED_UP: 'success',
  OUT_FOR_DELIVERY: 'info',
  DELIVERED: 'success',
  HANDED_TO_TECHNICIAN: 'info',
  COMPLETED: 'success',
  CANCELLED: 'neutral',
  REJECTED_BY_SHOP: 'danger',
  RETURN_REQUESTED: 'warning',
  RETURNED: 'neutral',
};

export const paymentTone: Record<PayStatus, Tone> = {
  AWAITING_TRANSFER: 'warning',
  RECEIPT_SUBMITTED: 'warning',
  CONFIRMED: 'success',
  REJECTED: 'danger',
  DUE: 'neutral',
  COLLECTED: 'success',
  EXPIRED: 'neutral',
  CANCELLED: 'neutral',
};

export const payoutTone: Record<PayoutStatus, Tone> = {
  DRAFT: 'neutral',
  APPROVED: 'info',
  PAID: 'success',
  CANCELLED: 'neutral',
};

export const bookingTone: Record<BookingStatus, Tone> = {
  HELD: 'neutral',
  AWAITING_PAYMENT: 'warning',
  PENDING_TECH_ACCEPT: 'warning',
  ACCEPTED: 'info',
  EN_ROUTE: 'info',
  IN_PROGRESS: 'info',
  COMPLETED: 'success',
  NEEDS_RESCHEDULE: 'danger',
  EXPIRED: 'neutral',
  CANCELLED_BY_BUYER: 'neutral',
  CANCELLED_BY_TECH: 'neutral',
  CANCELLED_BY_ADMIN: 'neutral',
  PART_DOES_NOT_FIT: 'warning',
};

export const disputeTone: Record<DisputeStatus, Tone> = {
  OPEN: 'warning',
  IN_REVIEW: 'info',
  RESOLVED: 'success',
  REJECTED: 'neutral',
};
