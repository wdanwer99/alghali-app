'use client';

import { useId, useState, type ReactNode } from 'react';
import { Button } from '@/components/ui/button';
import type { Dictionary } from '@/i18n/dictionaries';
import { fill } from '@/lib/format';
import { Notice } from './interactive';
import { Panel } from './ui';

type Values = {
  commissionPercent: number;
  bookingFeeSdg: number;
  mobileDepositSdg: number;
  slotHoldMinutes: number;
  paymentWindowMinutes: number;
  techAcceptTimeoutMinutes: number;
  cancelCutoffHours: number;
  returnWindowDays: number;
  travelFeeBands: { maxKm: number; sdg: number }[];
  bankakAccountName: string;
  bankakAccountNumber: string;
};

/** Demo only: saving shows a note and sends nothing (wired to Supabase in M6). */
export function SettingsForm({
  values,
  d,
  common,
}: {
  values: Values;
  d: Dictionary['settings'];
  common: Dictionary['common'];
}) {
  const [saved, setSaved] = useState(false);
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (e.currentTarget.reportValidity()) setSaved(true);
      }}
      onChange={() => setSaved(false)}
      className="flex flex-col gap-6"
    >
      <Notice
        message={saved ? d.savedNote : null}
        onDismiss={() => setSaved(false)}
        closeLabel={common.close}
      />

      <Section title={d.fees}>
        <NumberField
          label={d.commission}
          name="commissionPercent"
          defaultValue={values.commissionPercent}
          min={0}
          max={30}
        />
        <NumberField
          label={d.bookingFee}
          name="bookingFeeSdg"
          defaultValue={values.bookingFeeSdg}
          min={0}
          step={500}
        />
        <NumberField
          label={d.deposit}
          name="mobileDepositSdg"
          defaultValue={values.mobileDepositSdg}
          min={0}
          step={500}
        />
      </Section>

      <Section title={d.timing}>
        <NumberField
          label={d.hold}
          name="slotHoldMinutes"
          defaultValue={values.slotHoldMinutes}
          min={1}
          max={60}
        />
        <NumberField
          label={d.paymentWindow}
          name="paymentWindowMinutes"
          defaultValue={values.paymentWindowMinutes}
          min={10}
        />
        <NumberField
          label={d.techTimeout}
          name="techAcceptTimeoutMinutes"
          defaultValue={values.techAcceptTimeoutMinutes}
          min={5}
        />
        <NumberField
          label={d.cancelCutoff}
          name="cancelCutoffHours"
          defaultValue={values.cancelCutoffHours}
          min={0}
        />
        <NumberField
          label={d.returnWindow}
          name="returnWindowDays"
          defaultValue={values.returnWindowDays}
          min={0}
        />
      </Section>

      <Section title={d.travelBands}>
        {values.travelFeeBands.map((band) => (
          <NumberField
            key={band.maxKm}
            label={fill(d.upToKm, { n: band.maxKm })}
            name={`travel-${band.maxKm}`}
            defaultValue={band.sdg}
            min={0}
            step={500}
          />
        ))}
      </Section>

      <Section title={d.bankak}>
        <TextField
          label={d.accountName}
          name="bankakAccountName"
          defaultValue={values.bankakAccountName}
        />
        <TextField
          label={d.accountNumber}
          name="bankakAccountNumber"
          defaultValue={values.bankakAccountNumber}
          numeric
        />
      </Section>

      <div className="flex justify-end">
        <Button type="submit" className="h-10 px-5">
          {d.save}
        </Button>
      </div>
    </form>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <Panel title={title}>
      <div className="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2 xl:grid-cols-3">{children}</div>
    </Panel>
  );
}

const inputClass =
  'h-10 w-full rounded-lg border border-input bg-card px-3 text-base tabular-nums outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30 user-invalid:border-destructive';

function NumberField({
  label,
  name,
  defaultValue,
  min,
  max,
  step,
}: {
  label: string;
  name: string;
  defaultValue: number;
  min?: number;
  max?: number;
  step?: number;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-sm font-medium">
        {label}
      </label>
      <input
        id={id}
        name={name}
        type="number"
        inputMode="numeric"
        required
        defaultValue={defaultValue}
        min={min}
        max={max}
        step={step}
        className={inputClass}
      />
    </div>
  );
}

function TextField({
  label,
  name,
  defaultValue,
  numeric,
}: {
  label: string;
  name: string;
  defaultValue: string;
  numeric?: boolean;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-sm font-medium">
        {label}
      </label>
      <input
        id={id}
        name={name}
        required
        defaultValue={defaultValue}
        inputMode={numeric ? 'numeric' : undefined}
        pattern={numeric ? '[0-9]{6,16}' : undefined}
        className={inputClass}
      />
    </div>
  );
}
