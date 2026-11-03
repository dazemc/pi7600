-- One-time module rename for an existing Pi7600 database.
--
-- The Serverpod module name changed from `pi7600` to `simcom_api`. Fresh
-- databases record `simcom_api` automatically; existing databases must update
-- their migration marker before the renamed service starts.
--
-- Run with the database service available:
--   sudo -u postgres psql -d pi7600 -f scripts/rename_migration_module.sql

UPDATE serverpod_migrations
SET module = 'simcom_api'
WHERE module = 'pi7600';
