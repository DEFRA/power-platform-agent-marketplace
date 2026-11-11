import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { namespaceFor } = require('../namespace.cjs') as { namespaceFor: (file: string) => string };

const root = path.resolve(__dirname, '..');
const bundles = fs
  .readdirSync(path.join(root, 'src'))
  .filter((file) => file.endsWith('.ts') && file !== 'global-types.ts')
  .map((file) => file.replace(/\.ts$/, '.js'));

function loadBundle(fileName: string): Record<string, unknown> {
  const code = fs.readFileSync(path.join(root, 'dist', fileName), 'utf8');
  const sandbox: Record<string, unknown> = {};
  vm.runInNewContext(code, Object.assign(sandbox, { window: sandbox }));
  return sandbox;
}

function resolvePath(target: Record<string, unknown>, dotted: string): unknown {
  return dotted
    .split('.')
    .reduce<unknown>((value, key) => (value as Record<string, unknown> | undefined)?.[key], target);
}

describe('bundle contract', () => {
  test('there is at least one script to bundle', () => {
    expect(bundles.length).toBeGreaterThan(0);
  });

  test.each(bundles)('%s is built and exposes functions on its namespace', (bundle) => {
    expect(fs.existsSync(path.join(root, 'dist', bundle))).toBe(true);

    const exposed = resolvePath(loadBundle(bundle), namespaceFor(bundle));
    expect(typeof exposed).toBe('object');

    const handlers = Object.values(exposed as Record<string, unknown>).filter(
      (member) => typeof member === 'function'
    );
    expect(handlers.length).toBeGreaterThan(0);
  });
});
