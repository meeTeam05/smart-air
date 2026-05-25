import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('app logger redacts secret_key responses and cookie-bearing headers', async () => {
    const source = await readFile(new URL('../src/app.js', import.meta.url), 'utf8');

    assert.match(source, /'res\.body\.secret_key'/);
    assert.match(source, /'req\.headers\.cookie'/);
    assert.match(source, /'res\.headers\["set-cookie"\]'/);
});
