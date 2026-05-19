import test from 'node:test';
import assert from 'node:assert/strict';

import { normalizeEmail, isValidEmail } from '../src/utils/parse.js';

test('normalizeEmail trims and lowercases string input', () => {
    assert.equal(normalizeEmail(' User@Example.COM '), 'user@example.com');
    assert.equal(normalizeEmail(null), null);
    assert.equal(normalizeEmail({ email: 'user@example.com' }), null);
});

test('isValidEmail enforces shared auth/invite email constraints', () => {
    assert.equal(isValidEmail('user@example.com'), true);
    assert.equal(isValidEmail(''), false);
    assert.equal(isValidEmail('not-an-email'), false);
    assert.equal(isValidEmail('a'.repeat(255)), false);
});
