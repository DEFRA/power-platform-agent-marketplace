import path from 'node:path';
import { globSync } from 'glob';
import { defineConfig } from 'rollup';
import commonjs from '@rollup/plugin-commonjs';
import namespace from './namespace.cjs';

// One IIFE bundle per compiled script (global-types.ts only imports typings). The global
// namespace comes from the file name only.
export default globSync('out/src/*.js', { ignore: 'out/src/global-types.js' }).flatMap((entry) => {
  const fileName = path.basename(entry);

  return defineConfig({
    input: entry,
    context: 'window',
    plugins: [commonjs()],
    output: {
      file: `dist/${fileName}`,
      format: 'iife',
      name: namespace.namespaceFor(fileName),
      extend: true,
      sourcemap: true,
    },
  });
});
