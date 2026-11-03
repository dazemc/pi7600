BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "users" ADD COLUMN "totp_secret" text;
ALTER TABLE "users" ADD COLUMN "totp_enabled" boolean NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "totp_recovery_codes" text;

--
-- MIGRATION VERSION FOR simcom_api
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('simcom_api', '20261103105809161-totp-fields', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261103105809161-totp-fields', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
