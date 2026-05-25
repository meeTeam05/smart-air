const REDACTED_LOG_VALUE = '[Redacted]';
const SENSITIVE_LOG_KEYS = new Set([
    'accesstoken',
    'authorization',
    'cookie',
    'password',
    'refreshtoken',
    'secret',
    'secretkey',
    'setcookie',
    'token',
]);

function normalizeLogKey(key) {
    return String(key).toLowerCase().replace(/[^a-z0-9]/g, '');
}

function isSensitiveLogKey(key) {
    return SENSITIVE_LOG_KEYS.has(normalizeLogKey(key));
}

function sanitizeLoggedValue(value, seen = new WeakSet()) {
    if (value == null || typeof value !== 'object') return value;
    if (value instanceof Date) return value;
    if (Buffer.isBuffer(value)) return value;
    if (seen.has(value)) return '[Circular]';

    seen.add(value);
    try {
        if (Array.isArray(value)) {
            return value.map((entry) => sanitizeLoggedValue(entry, seen));
        }

        const sanitized = {};
        for (const [key, nestedValue] of Object.entries(value)) {
            sanitized[key] = isSensitiveLogKey(key)
                ? REDACTED_LOG_VALUE
                : sanitizeLoggedValue(nestedValue, seen);
        }
        return sanitized;
    } finally {
        seen.delete(value);
    }
}

export function sanitizeLoggedError(error) {
    if (!error || typeof error !== 'object') return error;

    const serialized = {
        type: error.name,
        message: error.message,
        stack: error.stack,
    };

    if ('code' in error) serialized.code = error.code;
    if ('statusCode' in error) serialized.statusCode = error.statusCode;
    if ('status' in error) serialized.status = error.status;

    for (const [key, value] of Object.entries(error)) {
        if (!(key in serialized)) {
            serialized[key] = value;
        }
    }

    return sanitizeLoggedValue(serialized);
}
