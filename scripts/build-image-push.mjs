#!/usr/bin/env node
// Multi-platform image build + push (default: GitHub Container Registry).
// Run via: npm run build:image:push
//
// Env overrides:
//   IMAGE         full image ref (default ghcr.io/kittipong-kum-ai/69-s3-app)
//   REGISTRY      default ghcr.io
//   OWNER         default kittipong-kum-ai
//   IMAGE_NAME    default 69-s3-app
//   TAG           default version from package.json
//   PLATFORMS     default linux/amd64,linux/arm64
//   CR_PAT        token for docker login (fallback: GHCR_TOKEN)
//   REGISTRY_USER default OWNER
//   PUSH_LATEST   "false" to skip the :latest tag
//   PUSH          "false" to build only (single platform + --load)
//   BUILDX_BUILDER default "multiarch"

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));

const registry = process.env.REGISTRY || 'ghcr.io';
const owner = process.env.OWNER || 'kittipong-kum-ai';
const name = process.env.IMAGE_NAME || '69-s3-app';
const tag = process.env.TAG || pkg.version;
const platforms = process.env.PLATFORMS || 'linux/amd64,linux/arm64';
const token = process.env.CR_PAT || process.env.GHCR_TOKEN || '';
const user = process.env.REGISTRY_USER || owner;
const pushLatest = (process.env.PUSH_LATEST || 'true') !== 'false';
const push = (process.env.PUSH || 'true') !== 'false';
const builder = process.env.BUILDX_BUILDER || 'multiarch';

const imageBase = (process.env.IMAGE || `${registry}/${owner}/${name}`).toLowerCase();
const tags = [`${imageBase}:${tag}`];
if (pushLatest && tag !== 'latest') tags.push(`${imageBase}:latest`);

if (!push && platforms.includes(',')) {
  throw new Error('PUSH=false supports only a single platform (set PLATFORMS to one platform)');
}

function run(cmd, args, opts = {}) {
  console.log(`\n> ${cmd} ${args.join(' ')}`);
  execFileSync(cmd, args, { stdio: 'inherit', ...opts });
}

try {
  execFileSync('docker', ['buildx', 'inspect', builder], { stdio: 'ignore' });
} catch {
  console.log(`\n> creating buildx builder "${builder}"`);
  run('docker', ['buildx', 'create', '--name', builder, '--driver', 'docker-container', '--use', '--bootstrap']);
}

if (push && token) {
  console.log(`\n> logging in to ${registry} as ${user}`);
  execFileSync('docker', ['login', registry, '-u', user, '--password-stdin'], {
    input: token,
    stdio: ['pipe', 'inherit', 'inherit'],
  });
}

const args = [
  'buildx', 'build',
  '--builder', builder,
  '--platform', platforms,
  '-f', join(root, 'Dockerfile'),
];
for (const t of tags) args.push('-t', t);
args.push(push ? '--push' : '--load');
args.push(root);

run('docker', args);

console.log('\nDone:');
for (const t of tags) console.log(`  ${t}`);
