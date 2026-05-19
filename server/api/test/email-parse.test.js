import test from 'node:test';
import assert from 'node:assert/strict';

import { isValidEmail, normalizeEmail, parsePositiveIntEnv } from '../src/utils/parse.js';

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

test('parsePositiveIntEnv accepts positive integers and falls back otherwise', () => {
    const envName = 'TEST_PARSE_POSITIVE_INT_ENV';
    const originalValue = process.env[envName];

    try {
        process.env[envName] = '15';
        assert.equal(parsePositiveIntEnv(envName, 4), 15);

        process.env[envName] = '0';
        assert.equal(parsePositiveIntEnv(envName, 4), 4);

        process.env[envName] = 'abc';
        assert.equal(parsePositiveIntEnv(envName, 4), 4);
    } finally {
        if (originalValue === undefined) {
            delete process.env[envName];
        } else {
            process.env[envName] = originalValue;
        }
    }
});
