// Guards the fork-local `nixpkgs-unstable` handling that upstream syncs keep
// clobbering, because upstream only ever knows `master` as an unstable primary
// branch. See the "Fork-local exception" in ci/github-script/supportedBranches.js.
import assert from 'node:assert/strict'
import test from 'node:test'
import {
  evaluateTargetBranchPolicy,
  getTargetBranchPolicy,
} from './check-target-branch-policy.ts'
import { classify } from './supportedBranches.js'

const defaults = {
  base: 'nixpkgs-unstable',
  head: 'topic-branch',
  maxRebuildCount: 0,
  rebuildsAllTests: false,
  onlyChangedFile: null,
}

test('classifies nixpkgs-unstable as an unstable primary branch', () => {
  const { stable, type, version } = classify('nixpkgs-unstable')
  assert.equal(stable, false)
  assert.equal(version, 'unstable')
  assert.ok(type.includes('primary'))
})

test('checks PRs targeting nixpkgs-unstable', () => {
  const policy = getTargetBranchPolicy({
    base: 'nixpkgs-unstable',
    head: 'topic-branch',
  })
  assert.equal(policy.shouldCheckMassRebuild, true)
  assert.equal(policy.shouldCheckNixosRebuild, true)
})

test('flags 1000 rebuilds on nixpkgs-unstable as a mass rebuild', () => {
  assert.equal(
    evaluateTargetBranchPolicy({ ...defaults, maxRebuildCount: 1000 }).decision,
    'mass-rebuild',
  )
})

test('flags NixOS test rebuilds on nixpkgs-unstable', () => {
  assert.equal(
    evaluateTargetBranchPolicy({ ...defaults, rebuildsAllTests: true })
      .decision,
    'nixos-rebuild',
  )
})

test('skips staging into nixpkgs-unstable', () => {
  assert.equal(
    evaluateTargetBranchPolicy({
      ...defaults,
      head: 'staging',
      maxRebuildCount: 24_000,
    }).decision,
    'skip-development-merge',
  )
})
