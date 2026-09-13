import { spawnSync } from 'node:child_process';
import { rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

const PACKAGES = {
  'src/equipment': {
    name: 'equipment',
    exports: {
      '.': './index.ts',
      './domain-objects/*': './domain-objects/*'
    }
  },
  'src/user': {
    name: 'user',
    exports: {
      '.': './index.ts',
      './domain-objects/*': './domain-objects/*'
    }
  },
  'src/support': {
    name: 'support',
    exports: {
      './domain-objects/*': './domain-objects/*'
    }
  }
};

function packageJsonFiles() {
  return Object.keys(PACKAGES).map((dir) => path.join(ROOT, dir, 'package.json'));
}

function writePackageJsonFiles() {
  for (const [dir, pkg] of Object.entries(PACKAGES)) {
    const file = path.join(ROOT, dir, 'package.json');
    const content = {
      name: pkg.name,
      version: '0.0.0',
      exports: pkg.exports
    };

    writeFileSync(file, JSON.stringify(content, undefined, '  ') + '\n');
  }
}

function removePackageJsonFiles() {
  for (const file of packageJsonFiles()) {
    rmSync(file, { force: true });
  }
}

try {
  writePackageJsonFiles();

  rmSync(path.join(ROOT, 'apidocs'), { force: true, recursive: true });

  const result = spawnSync('pnpm', ['exec', 'typedoc'], {
    cwd: ROOT,
    stdio: 'inherit'
  });

  process.exitCode = result.status ?? 1;
} finally {
  removePackageJsonFiles();
}
