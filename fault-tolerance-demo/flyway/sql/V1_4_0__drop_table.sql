-- https://www.cockroachlabs.com/docs/stable/online-schema-changes.html

BEGIN;
  DROP TABLE fruits;
COMMIT;
