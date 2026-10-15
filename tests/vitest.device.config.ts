import { defineConfig } from 'vitest/config';

/**
 * The acceptance journey on a phone (`pnpm journey:e2e`): drives the buyer and partner
 * apps on a running emulator against alghali-test. Not part of `pnpm test`.
 */
export default defineConfig({
  test: {
    include: ['device/**/*.device.ts'],
    // Each step builds and runs an app on the device.
    testTimeout: 30 * 60_000,
    hookTimeout: 5 * 60_000,
    fileParallelism: false,
  },
});
