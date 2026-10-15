// `pnpm perf:e2e [-- -d <device>] [--only buyer|partner]`: how the apps perform on a phone (PLAN §2 M7: a low-end
// Android 8 emulator with 2 GB). For each app, in profile mode against alghali-dev:
//   - time to the first frame (flutter run --trace-startup),
//   - frame build and raster times while scrolling the main screens (integration_test/
//     perf_test.dart; the buyer as a guest, the partner as the demo shop owner — reads only),
//   - memory in use afterwards (dumpsys meminfo).
// Prints a table for docs/PERFORMANCE.md. The demo password goes through a temporary
// defines file, never the command line.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readEnvFile } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const args = process.argv.slice(2).filter((a) => a !== '--');
const i = args.indexOf('-d');
const device = i >= 0 ? args[i + 1] : undefined;
const o = args.indexOf('--only');
const apps = o >= 0 ? [args[o + 1]] : ['buyer', 'partner'];
const env = readEnvFile(join(root, '.env')) ?? {};
const adb = join(process.env.LOCALAPPDATA ?? '', 'Android/Sdk/platform-tools/adb');
const onDevice = device ? ['-d', device] : [];

const flutter = (cwd, flutterArgs) =>
  spawnSync('flutter', flutterArgs, { cwd, stdio: 'inherit', shell: true }).status;

const results = [];
for (const app of apps) {
  const dir = join(root, 'apps', app);
  const pkg = `sd.alghali.${app}`;
  const tmp = mkdtempSync(join(tmpdir(), 'alghali-perf-'));
  const file = join(tmp, 'defines.json');
  try {
    writeFileSync(
      file,
      JSON.stringify({
        ...JSON.parse(readFileSync(join(dir, 'env', 'dev.json'), 'utf8')),
        E2E_SHOP_EMAIL: 'owner.nour@demo.alghali.invalid',
        E2E_PASSWORD: env.DEMO_PASSWORD ?? '',
      }),
      { mode: 0o600 },
    );
    const defines = `--dart-define-from-file=${file}`;
    spawnSync(adb, [...(device ? ['-s', device] : []), 'shell', 'pm', 'clear', pkg]);

    // Time to the first frame (the welcome screen), from a cold start.
    rmSync(join(dir, 'build', 'start_up_info.json'), { force: true });
    flutter(dir, ['run', '--profile', '--trace-startup', defines, ...onDevice]);
    const startup = existsSync(join(dir, 'build', 'start_up_info.json'))
      ? JSON.parse(readFileSync(join(dir, 'build', 'start_up_info.json'), 'utf8'))
      : {};

    // Scrolling, then the memory it holds.
    spawnSync(adb, [...(device ? ['-s', device] : []), 'shell', 'pm', 'clear', pkg]);
    rmSync(join(dir, 'build', 'integration_response_data.json'), { force: true });
    const status = flutter(dir, [
      'drive',
      '--profile',
      '--keep-app-running',
      // watchPerformance talks to the VM service directly, which DDS would hold.
      '--no-dds',
      '--driver=test_driver/perf_driver.dart',
      '--target=integration_test/perf_test.dart',
      defines,
      ...onDevice,
    ]);
    const frames = existsSync(join(dir, 'build', 'integration_response_data.json'))
      ? JSON.parse(readFileSync(join(dir, 'build', 'integration_response_data.json'), 'utf8'))[app]
      : undefined;
    const meminfo = spawnSync(adb, [
      ...(device ? ['-s', device] : []),
      'shell',
      'dumpsys',
      'meminfo',
      pkg,
    ]).stdout?.toString();
    const pss = Number(/TOTAL(?: PSS)?:?\s+(\d+)/.exec(meminfo ?? '')?.[1] ?? NaN);
    results.push({ app, status, startup, frames, pssMb: pss / 1024 });
  } finally {
    rmSync(tmp, { recursive: true, force: true });
    rmSync(
      join(dir, 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'),
      {
        force: true,
      },
    );
  }
}

const ms = (us) => (us === undefined ? '—' : `${Math.round(us / 1000)} ms`);
const f = (v) => (v === undefined ? '—' : `${Number(v).toFixed(1)} ms`);
console.log(`\n| | ${apps.join(' | ')} |\n|---|${apps.map(() => '---|').join('')}`);
const row = (label, pick) => console.log(`| ${label} | ${results.map(pick).join(' | ')} |`);
row('First frame after a cold start', (r) => ms(r.startup.timeToFirstFrameMicros));
row('Frames measured', (r) => r.frames?.frame_count ?? '—');
row('Frame build, average / 90th / worst', (r) =>
  r.frames
    ? `${f(r.frames.average_frame_build_time_millis)} / ${f(r.frames['90th_percentile_frame_build_time_millis'])} / ${f(r.frames.worst_frame_build_time_millis)}`
    : '—',
);
row('Frame raster, average / 90th / worst', (r) =>
  r.frames
    ? `${f(r.frames.average_frame_rasterizer_time_millis)} / ${f(r.frames['90th_percentile_frame_rasterizer_time_millis'])} / ${f(r.frames.worst_frame_rasterizer_time_millis)}`
    : '—',
);
row('Frames over budget (build / raster)', (r) =>
  r.frames
    ? `${r.frames.missed_frame_build_budget_count} / ${r.frames.missed_frame_rasterizer_budget_count}`
    : '—',
);
row('Memory in use after scrolling (PSS)', (r) =>
  Number.isFinite(r.pssMb) ? `${Math.round(r.pssMb)} MB` : '—',
);
process.exitCode = results.every((r) => r.status === 0) ? 0 : 1;
