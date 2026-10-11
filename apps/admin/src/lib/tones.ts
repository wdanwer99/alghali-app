import type { Tone } from '@/components/admin/ui';
import type {
  BookingStatus,
  DisputeRow,
  OrderStatus,
  PaymentStatus,
  PayoutRow,
} from '@/lib/demo/data';

/** Status colours match the phone apps; red is never used for a status. */
export const orderTone: Record<OrderStatus, Tone> = {
  pendingPayment: 'warning',
  paymentReview: 'warning',
  confirmed: 'info',
  ready: 'success',
  pickedUp: 'success',
  handedToTechnician: 'info',
  completed: 'success',
  cancelled: 'danger',
};

export const paymentTone: Record<PaymentStatus, Tone> = {
  awaitingTransfer: 'warning',
  receiptSubmitted: 'warning',
  confirmed: 'success',
  due: 'neutral',
  collected: 'success',
  expired: 'neutral',
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

export const payoutTone: Record<PayoutRow['status'], Tone> = {
  draft: 'neutral',
  approved: 'info',
  paid: 'success',
};

export const disputeTone: Record<DisputeRow['status'], Tone> = {
  open: 'warning',
  investigating: 'info',
  resolved: 'success',
};
