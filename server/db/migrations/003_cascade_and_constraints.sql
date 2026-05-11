-- Migration 003: Fix foreign key CASCADE rules + add CHECK constraints
-- Wrapping in transaction for atomicity

BEGIN;

-- ── Foreign key CASCADE fixes ────────────────────────────────────────────────

-- homes.owner_id → SET NULL (home survives if owner deleted; ownership transferable)
ALTER TABLE homes DROP CONSTRAINT IF EXISTS homes_owner_id_fkey;
ALTER TABLE homes ADD CONSTRAINT homes_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL;

-- devices.home_id → CASCADE (delete home → delete its devices)
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_home_id_fkey;
ALTER TABLE devices ADD CONSTRAINT devices_home_id_fkey
    FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE;

-- devices.room_id → SET NULL (delete room → unassign device, don't delete it)
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_room_id_fkey;
ALTER TABLE devices ADD CONSTRAINT devices_room_id_fkey
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL;

-- devices.type_id → SET NULL (if device type removed, device stays)
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_type_id_fkey;
ALTER TABLE devices ADD CONSTRAINT devices_type_id_fkey
    FOREIGN KEY (type_id) REFERENCES device_types(id) ON DELETE SET NULL;

-- devices.owner_id → SET NULL (device survives if registrar deleted)
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_owner_id_fkey;
ALTER TABLE devices ADD CONSTRAINT devices_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL;

-- commands.user_id → SET NULL (command history survives user deletion)
ALTER TABLE commands DROP CONSTRAINT IF EXISTS commands_user_id_fkey;
ALTER TABLE commands ADD CONSTRAINT commands_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

-- automations.user_id → SET NULL (automation survives user deletion)
ALTER TABLE automations DROP CONSTRAINT IF EXISTS automations_user_id_fkey;
ALTER TABLE automations ADD CONSTRAINT automations_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

-- ── CHECK constraints ────────────────────────────────────────────────────────

-- Ensure only valid roles in home_members
DO $$ BEGIN
    ALTER TABLE home_members ADD CONSTRAINT home_members_role_check
        CHECK (role IN ('owner', 'admin', 'member'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Ensure only valid command statuses
DO $$ BEGIN
    ALTER TABLE commands ADD CONSTRAINT commands_status_check
        CHECK (status IN ('pending', 'sent', 'done', 'failed'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMIT;
