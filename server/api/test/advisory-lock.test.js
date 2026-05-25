import test from 'node:test';
import assert from 'node:assert/strict';

import { advisoryLockId } from '../src/utils/advisory-lock.js';

test('advisoryLockId is deterministic and returns a signed 64-bit integer string', () => {
    const first = advisoryLockId('quota:devices:11111111-1111-4111-8111-111111111111');
    const second = advisoryLockId('quota:devices:11111111-1111-4111-8111-111111111111');
    const other = advisoryLockId('quota:devices:22222222-2222-4222-8222-222222222222');

    assert.equal(first, second);
    assert.notEqual(first, other);

    const value = BigInt(first);
    const min = -(1n << 63n);
    const max = (1n << 63n) - 1n;
    assert.ok(value >= min);
    assert.ok(value <= max);
});
