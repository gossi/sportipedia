#!/usr/bin/env node
// The `pnpm spgen` binding: a thin wrapper around the Rust binary, the same
// contract the mix tasks are for the Elixir escript. The binary is built on
// demand (SPARCH_NO_AUTOBUILD=1 opts out) so the generator works even when
// the app it is called to repair does not compile.

import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const workspace = join(here, '..', '..'); // node/bin -> node -> tools/sparch
const binary = join(workspace, 'target', 'release', 'sparch-typescript');

function newestMtime(dir) {
  let newest = 0;
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      newest = Math.max(newest, newestMtime(path));
    } else if (entry.endsWith('.rs') || entry.endsWith('.toml')) {
      newest = Math.max(newest, stat.mtimeMs);
    }
  }
  return newest;
}

if (process.env.SPARCH_NO_AUTOBUILD !== '1') {
  const built = existsSync(binary) ? statSync(binary).mtimeMs : 0;
  const sources = newestMtime(join(workspace, 'crates'));
  if (sources > built) {
    const build = spawnSync('cargo', ['build', '--release', '--quiet', '-p', 'sparch-typescript'], {
      cwd: workspace,
      stdio: 'inherit'
    });
    if (build.status !== 0) {
      process.exit(build.status ?? 1);
    }
  }
}

if (!existsSync(binary)) {
  console.error(`error: sparch binary not found: ${binary} (install Rust or build with cargo)`);
  process.exit(1);
}

const result = spawnSync(binary, process.argv.slice(2), { stdio: 'inherit' });
process.exit(result.status ?? 1);
