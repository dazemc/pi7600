BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "users" ADD COLUMN "token_version" bigint NOT NULL DEFAULT 0;

--
-- MIGRATION VERSION FOR simcom_api
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('simcom_api', '20261103110317439-token-version', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261103110317439-token-version', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
