import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DEFAULT_OTA_FILES_DIR = path.resolve(__dirname, '../../../ota-files');
const DEFAULT_OTA_PUBLIC_BASE_URL = 'https://minhnhat05.xyz';
const ESP_IMAGE_HEADER_MAGIC = 0xE9;
const ESP_IMAGE_HEADER_SIZE = 24;
const ESP_IMAGE_HASH_APPENDED_OFFSET = 23;
const ESP_IMAGE_DIGEST_SIZE = 32;

function otaFilesDir() {
    return process.env.OTA_FILES_DIR || DEFAULT_OTA_FILES_DIR;
}

function otaPublicBaseUrl() {
    return (process.env.OTA_PUBLIC_BASE_URL || DEFAULT_OTA_PUBLIC_BASE_URL).replace(/\/+$/, '');
}

function versionSegments(version) {
    return version.split('.').map((segment) => {
        const numeric = Number(segment);
        return Number.isInteger(numeric) && String(numeric) === segment
            ? { numeric, raw: segment }
            : { numeric: null, raw: segment };
    });
}

function compareVersionsDesc(left, right) {
    const leftSegments = versionSegments(left);
    const rightSegments = versionSegments(right);
    const segmentCount = Math.max(leftSegments.length, rightSegments.length);

    for (let i = 0; i < segmentCount; i++) {
        const leftSegment = leftSegments[i] ?? { numeric: 0, raw: '' };
        const rightSegment = rightSegments[i] ?? { numeric: 0, raw: '' };
        if (leftSegment.numeric !== null && rightSegment.numeric !== null) {
            if (leftSegment.numeric !== rightSegment.numeric) {
                return rightSegment.numeric - leftSegment.numeric;
            }
            continue;
        }

        const lexical = rightSegment.raw.localeCompare(leftSegment.raw);
        if (lexical !== 0) return lexical;
    }

    return right.localeCompare(left);
}

function artifactUrl(filename) {
    return `${otaPublicBaseUrl()}/ota/${encodeURIComponent(filename)}`;
}

export async function listOtaArtifacts() {
    const entries = await readdir(otaFilesDir(), { withFileTypes: true });
    return entries
        .filter((entry) => entry.isFile() && entry.name.endsWith('.bin'))
        .map((entry) => {
            const filename = entry.name;
            const version = path.basename(filename, '.bin');
            return {
                version,
                filename,
                url: artifactUrl(filename),
            };
        })
        .sort((left, right) => compareVersionsDesc(left.version, right.version));
}

export async function resolveOtaArtifact(version) {
    const artifacts = await listOtaArtifacts();
    const artifact = artifacts.find((item) => item.version === version);
    if (!artifact) return null;

    return {
        ...artifact,
        filePath: path.join(otaFilesDir(), artifact.filename),
    };
}

export async function computeOtaArtifactSha256(filePath) {
    const content = await readFile(filePath);
    if (
        content.length >= ESP_IMAGE_HEADER_SIZE + ESP_IMAGE_DIGEST_SIZE &&
        content[0] === ESP_IMAGE_HEADER_MAGIC &&
        content[ESP_IMAGE_HASH_APPENDED_OFFSET] === 1
    ) {
        const imageContent = content.subarray(0, content.length - ESP_IMAGE_DIGEST_SIZE);
        const appendedDigest = content.subarray(content.length - ESP_IMAGE_DIGEST_SIZE);
        const computedDigest = createHash('sha256').update(imageContent).digest();
        if (!computedDigest.equals(appendedDigest)) {
            throw new Error('OTA artifact appended hash is invalid');
        }
        return appendedDigest.toString('hex');
    }

    return createHash('sha256').update(content).digest('hex');
}
