export function parseDateOr(qs, fallback) {
    if (qs == null) return fallback;
    const d = new Date(qs);
    if (isNaN(d.getTime())) return null;
    return d;
}

export function parsePositiveInt(s, fallback, max) {
    if (s == null) return fallback;
    const n = parseInt(s, 10);
    if (Number.isNaN(n) || n < 0) return null;
    return max !== undefined ? Math.min(n, max) : n;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseUuid(value) {
    return typeof value === 'string' && UUID_RE.test(value) ? value : null;
}

export function cleanRequiredString(value) {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
}

export function cleanOptionalString(value, { allowNull = false } = {}) {
    if (value === undefined) return undefined;
    if (value === null && allowNull) return null;
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeEmail(email) {
    return typeof email === 'string' ? email.trim().toLowerCase() : null;
}

export function isValidEmail(email) {
    return typeof email === 'string' && email.length <= 254 && EMAIL_RE.test(email);
}
