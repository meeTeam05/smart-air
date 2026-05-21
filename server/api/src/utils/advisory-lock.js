import { createHash } from 'node:crypto';

export function advisoryLockId(key) {
    if (typeof key !== 'string' || key.trim() === '') {
        throw new TypeError('advisory lock key must be a non-empty string');
    }

    return createHash('sha256').update(key).digest().readBigInt64BE(0).toString();
}
