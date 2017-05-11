
-- ---------------------------------------------------------------------------------------------------

\set expected_version 91

\set ON_ERROR_STOP on

    -- warn that we detected the schema version mismatch:
SELECT ('The patch only applies to schema version '
    || CAST(:expected_version AS VARCHAR)
    || ', but the current schema version is '
    || meta_value
    || ', so skipping the rest.') as incompatible_msg
    FROM hive_meta WHERE meta_key='hive_sql_schema_version' AND meta_value!=CAST(:expected_version AS VARCHAR);

    -- cause division by zero only if current version differs from the expected one:
INSERT INTO hive_meta (meta_key, meta_value)
   SELECT 'this_should_never_be_inserted', 1 FROM hive_meta WHERE 1 != 1/CAST( (meta_key!='hive_sql_schema_version' OR meta_value=CAST(:expected_version AS VARCHAR)) AS INTEGER );

SELECT ('The patch seems to be compatible with schema version '
    || CAST(:expected_version AS VARCHAR)
    || ', applying the patch...') AS compatible_msg;


-- ----------------------------------<actual_patch> -------------------------------------------------

-- part_1: changes to introduce 'SUBMITTED' state of Workers:

ALTER TABLE worker      ALTER COLUMN    meadow_host     DROP NOT NULL;
ALTER TABLE worker      ALTER COLUMN    meadow_host     SET DEFAULT NULL;

ALTER TABLE worker      ALTER COLUMN    when_born       DROP NOT NULL;
ALTER TABLE worker      ALTER COLUMN    when_born       SET DEFAULT NULL;

ALTER TABLE worker      ADD COLUMN      when_submitted  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- part_2: changes to allow extra meadow-specific exit statuses to be representable in the worker table:

ALTER TABLE worker      ALTER COLUMN   cause_of_death  SET DATA TYPE   VARCHAR(255);

-- ----------------------------------</actual_patch> -------------------------------------------------


    -- increase the schema version by one and register the patch:
UPDATE hive_meta SET meta_value= (CAST(meta_value AS INTEGER) + 1) WHERE meta_key='hive_sql_schema_version';
INSERT INTO hive_meta (meta_key, meta_value) SELECT 'patched_to_' || meta_value, CURRENT_TIMESTAMP FROM hive_meta WHERE meta_key = 'hive_sql_schema_version';