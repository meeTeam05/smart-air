export function normalizeDeviceId(value) {
    return typeof value === 'string' ? value.trim().toLowerCase() : value;
}
