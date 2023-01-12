-- https://www.cockroachlabs.com/docs/stable/online-schema-changes.html

BEGIN;
  SAVEPOINT cockroach_restart;
  SET sql_safe_updates = false;
  ALTER TABLE fruits DROP CONSTRAINT name;
  SELECT name, color, inventory_count FROM fruits;
  SET sql_safe_updates = false;
  RELEASE SAVEPOINT cockroach_restart;
COMMIT;
