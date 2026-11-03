BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "audit_events" (
    "id" bigserial PRIMARY KEY,
    "created_at" timestamp without time zone NOT NULL,
    "event_type" text NOT NULL,
    "user_name" text,
    "remote_address" text,
    "success" boolean NOT NULL,
    "detail" text
);

-- Indexes
CREATE INDEX "audit_events_created_at_idx" ON "audit_events" USING btree ("created_at");


--
-- MIGRATION VERSION FOR simcom_api
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('simcom_api', '20261103110917588-audit-events', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261103110917588-audit-events', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
