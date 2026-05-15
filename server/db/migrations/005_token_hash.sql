-- Migration 005: Refresh token hashing at rest
-- Revoke existing refresh tokens because stored token format changes from raw UUIDs to SHA-256 hex.

BEGIN;

DELETE FROM refresh_tokens;

COMMIT;
