const MAC_RE = /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/;

export function normalizeDeviceId(value) {
    if (typeof value !== 'string') return null;
    const normalized = value.trim().toLowerCase();
    return MAC_RE.test(normalized) ? normalized : null;
}
