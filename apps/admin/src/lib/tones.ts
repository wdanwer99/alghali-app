import type { Tone } from '@/components/admin/ui';
import type { PayoutStatus, PayStatus, SubStatus } from '@/lib/data/commerce';
import type { BookingStatus, DisputeRow } from '@/lib/demo/data';

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
  awaitingPayment: 'warning',
  pendingTechAccept: 'warning',
  accepted: 'info',
  enRoute: 'info',
  inProgress: 'info',
  completed: 'success',
  cancelledByBuyer: 'danger',
};

export const disputeTone: Record<DisputeRow['status'], Tone> = {
  open: 'warning',
  investigating: 'info',
  resolved: 'success',
};
