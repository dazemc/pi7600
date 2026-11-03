BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE INDEX "messages_fingerprint_idx" ON "messages" USING btree ("message_type", "message_contents", "message_date", "message_time");

--
-- MIGRATION VERSION FOR simcom_api
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('simcom_api', '20261103100522591-sms-fingerprint-index', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261103100522591-sms-fingerprint-index', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
