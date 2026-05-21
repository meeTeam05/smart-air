import test from 'node:test';
import assert from 'node:assert/strict';

import { waitForMqttClientEnd } from '../src/plugins/mqtt.js';

test('waitForMqttClientEnd resolves only after mqtt client close callback fires', async () => {
    let finishClose;
    const calls = [];
    const client = {
        end(force, options, callback) {
            calls.push({ force, options });
            finishClose = callback;
        },
    };

    let settled = false;
    const pending = waitForMqttClientEnd(client).then(() => {
        settled = true;
    });

    await Promise.resolve();
    assert.equal(settled, false);
    assert.deepEqual(calls, [{ force: false, options: {} }]);

    finishClose();
    await pending;
    assert.equal(settled, true);
});
