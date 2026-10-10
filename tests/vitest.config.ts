import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['**/*.test.ts'],
    exclude: ['**/node_modules/**'],
    // DB tests talk to a hosted project over the internet.
    testTimeout: 30_000,
    hookTimeout: 30_000,
    // Tests share one database; run files one after another.
    fileParallelism: false,
  },
});
