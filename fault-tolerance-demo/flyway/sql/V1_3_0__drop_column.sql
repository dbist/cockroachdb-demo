-- https://www.cockroachlabs.com/docs/stable/online-schema-changes.html

BEGIN;
  SAVEPOINT cockroach_restart;
  SET sql_safe_updates = false;
  ALTER TABLE fruits DROP COLUMN inventory_count;
  SELECT * FROM fruits;
  SET sql_safe_updates = true;
  RELEASE SAVEPOINT cockroach_restart;
COMMIT;
