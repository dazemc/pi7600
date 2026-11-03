BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "messages" (
    "id" bigserial PRIMARY KEY,
    "message_index" text,
    "message_type" text NOT NULL,
    "message_originating_address" text,
    "message_destination_address" text,
    "message_date" text NOT NULL,
    "message_time" text NOT NULL,
    "message_contents" text NOT NULL,
    "partial_key" text,
    "partial_count" bigint,
    "partial_index" bigint,
    "is_partial" boolean NOT NULL,
    "in_sim_memory" boolean,
    "is_sent" boolean
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "users" (
    "id" bigserial PRIMARY KEY,
    "user_name" text NOT NULL,
    "user_password" text NOT NULL,
    "user_full_name" text,
    "user_email" text,
    "is_disabled" boolean NOT NULL DEFAULT false,
    "is_admin" boolean NOT NULL DEFAULT false
);

-- Indexes
CREATE UNIQUE INDEX "users__user_name__unique_idx" ON "users" USING btree ("user_name");


--
-- MIGRATION VERSION FOR simcom_api
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('simcom_api', '20261103045113867', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261103045113867', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
