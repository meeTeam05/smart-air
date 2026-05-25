import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import { sanitizeLoggedError } from '../src/utils/log-sanitize.js';

test('logger serializer redacts sensitive fields nested under err', async () => {
    const logLines = [];
    const app = Fastify({
        logger: {
            level: 'info',
            stream: {
                write(line) {
                    logLines.push(line);
                },
            },
            serializers: {
                err: sanitizeLoggedError,
            },
        },
    });

    try {
        const err = new Error('boom');
        err.password = 'secret-pass';
        err.token = 'secret-token';
        err.requestPayload = {
            password: 'nested-pass',
            authorization: 'Bearer nested-secret',
        };

        app.log.error({ err }, 'request failed');

        assert.equal(logLines.length, 1);
        const output = logLines[0];
        assert.match(output, /"\[Redacted\]"/);
        assert.doesNotMatch(output, /secret-pass/);
        assert.doesNotMatch(output, /secret-token/);
        assert.doesNotMatch(output, /nested-pass/);
        assert.doesNotMatch(output, /nested-secret/);
        assert.match(output, /"message":"boom"/);
    } finally {
        await app.close();
    }
});
