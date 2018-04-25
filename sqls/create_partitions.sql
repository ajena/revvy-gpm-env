CREATE OR REPLACE FUNCTION gpm.create_index_if_not_exists (index_method text, table_name text, column_name text, index_name text) RETURNS void AS $$
DECLARE
    schema_name VARCHAR;
BEGIN
    schema_name = 'gpm';
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_class c
        JOIN   pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relname = index_name
        AND    n.nspname = schema_name
        ) THEN

        EXECUTE 'CREATE INDEX ' || index_name || ' ON ' || schema_name || '.' || table_name || ' USING ' || index_method || ' (' || column_name || ')';

    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error when creating % on table %: %, SQL state: %.', index_name, table_name, SQLERRM, SQLSTATE;
END;
$$ LANGUAGE plpgsql;

--
-- NOTE: Tables are created in the gpm schema.
--
-- STEPS:

--  0. Verify that all records in mnadvsimulation__c has a createddate.
--  1. Create a backup of mnadvsimulationoutput__c table. Name the new table like this - mnadvsimulationoutput__c_bak_<current_datetime>.
--  2. Delete the orphan (where the corresponding mnadvsimulation__c record doesn't exist anymore) records from mnadvsimulationoutput__c.
--  3. Add column mnadvsimcreateddate__c to mnadvsimulationoutput__c to capture the simulation scenario creation date.
--     This new column will act as the partition key for the quarterly range partition.
--  4. Update this column with appropriate value by joining mnadvsimulation__c table.
--  5. Verify that there are zero rows with NULL value in mnadvsimcreateddate__c column.
--  6. At this point create another backup table mnadvsimulationoutput__c_ext from mnadvsimulationoutput__c.
--     We'll use this new table as the source table to insert records into mnadvsimulationoutput__c after creating child tables and INSERT rules.
--  7. Starting from the earliest quarter(based on least createddate in mnadvsimulation__c table) till current quarter,
--     - create child tables of mnadvsimulationoutput__c master table.
--     - create PK, Unique Key constraints
--     - create appropriate indexes
--     - create INSERT RULEs for each child table created
--  8. TRUNCATE mnadvsimulationoutput__c table.
--  9. Now copy everything from mnadvsimulationoutput__c_ext to mnadvsimulationoutput__c table.
-- 10. Verify that there are zero records in 'ONLY mnadvsimulationoutput__c' table.
--
-- At any point, if there are any errors, then revert to original state by following actions.
-- This should be taken care by simply raising an exception which will rollback the entire transaction.
--     - log appropriate message
--     - drop all child tables
--     - drop mnadvsimulationoutput__c_ext table
--     - drop column mnadvsimcreateddate__c from mnadvsimulationtoutput__c table
--     - copy all backed-up data from mnadvsimulationoutput__c_bak_<current_datetime> to mnadvsimulationoutput__c table.
--     - drop mnadvsimulationoutput__c_bak_<current_datetime> table.
--
DO $PARTITION_MNADVSIMULATIONOUTPUT$
DECLARE
    -- MUST READ: If the SFDC Org has namespace, you must specify it with ALL lowercase and double underscores, for example: 'gpmnightly__'
    sf_namespace VARCHAR := '';

    min_createddate TIMESTAMP;
    start_year INTEGER;
    start_quarter INTEGER;
    curr_year INTEGER;
    curr_quarter INTEGER;
    partition_start_date DATE;
    partition_next_start_date DATE;
    sim_table_name VARCHAR := sf_namespace || 'mnadvsimulation__c';
    sim_table_fk_name VARCHAR := sf_namespace || 'mnadvsimulation__c';
    master_table_name VARCHAR := sf_namespace || 'mnadvsimulationoutput__c_bak';
    master_table_short_name VARCHAR := 'mnadvsimoutputbak';
    master_ext_table_name VARCHAR := master_table_name || '_ext';
    date_range_part_col_name VARCHAR := sf_namespace || 'mnadvsimcreateddate__c';
    check_constraint_text VARCHAR;
    child_table_name VARCHAR;
    child_table_name_for_index VARCHAR;
    script_text VARCHAR;
    row_count INTEGER;
BEGIN

    IF LENGTH(sf_namespace) = 0 THEN
        RAISE NOTICE 'namespace not specified';
    ELSE
        RAISE NOTICE 'namespace: %', sf_namespace;
    END IF;

    --  0. Verify that all records in mnadvsimulation__c has a createddate.
    RAISE INFO 'Verifying data in %...', sim_table_name;
    BEGIN
        script_text := 'SELECT COUNT(*) FROM gpm.' || sim_table_name || ' WHERE createddate IS NULL';
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text INTO row_count;
        IF row_count > 0 THEN
            RAISE EXCEPTION '% rows in % have NULL createddate. Please re-verify/clean up the data before proceeding again.', row_count, sim_table_name;
        END IF;
    END;

    --  1. Create a backup of mnadvsimulationoutput__c table.
    --     Name the new table like this - mnadvsimulationoutput__c_bak_<current_datetime>.
    RAISE INFO 'Creating backup of %', master_table_name;
    BEGIN
        script_text := 'CREATE TABLE gpm.' || master_table_name || '_bak_' || TO_CHAR(now(), 'YYYYMMDDHH24MISS') || ' AS '
                    || 'SELECT * FROM gpm.' || master_table_name;
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;
    END;

    --  2. Delete the orphan (where the corresponding mnadvsimulation__c record doesn't exist anymore) records from mnadvsimulationoutput__c.
    RAISE INFO 'Deleting orphan records from %', master_table_name;
    BEGIN
        script_text := 'DELETE FROM gpm.' || master_table_name || ' '
                    || 'WHERE ' || sim_table_fk_name || ' NOT IN ('
                    || 'SELECT sfid FROM gpm.' || sim_table_name
                    || ')';
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;
    END;

    --  3. Add column mnadvsimcreateddate__c to mnadvsimulationoutput__c to capture the simulation scenario creation date.
    --     This new column will act as the partition key for the quarterly range partition.
    RAISE INFO 'Adding column % to %', date_range_part_col_name, master_table_name;
    BEGIN
        script_text := 'ALTER TABLE gpm.' || master_table_name || ' '
                    || 'ADD COLUMN ' || date_range_part_col_name || ' timestamp without time zone';
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;
    END;

    --  4. Update this column with appropriate value by joining mnadvsimulation__c table.
    RAISE INFO 'Updating column %', date_range_part_col_name;
    BEGIN
        script_text := 'UPDATE gpm.' || master_table_name || ' aso '
                    || 'SET ' || date_range_part_col_name || ' = asim.createddate '
                    || 'FROM gpm.' || sim_table_name || ' asim '
                    || 'WHERE aso.' || sim_table_fk_name || ' = asim.sfid';
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;
    END;

    --  5. Verify that there are zero rows with NULL value in mnadvsimcreateddate__c column.
    RAISE INFO 'Running Verification...';
    BEGIN
        script_text := 'SELECT COUNT(*) FROM gpm.' || master_table_name || ' WHERE ' || date_range_part_col_name || ' IS NULL';
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text INTO row_count;
        IF row_count > 0 THEN
            RAISE EXCEPTION '% rows in % have NULL % column. Please re-verify the data before proceeding again.', row_count, master_table_name, date_range_part_col_name;
        END IF;
    END;

    --  6. At this point create another backup table mnadvsimulationoutput__c_ext from mnadvsimulationoutput__c.
    --     We'll use this new table as the source table to insert records into mnadvsimulationoutput__c after creating child tables and INSERT rules.
    RAISE INFO 'Creating a copy of %(with the column %) AS %', master_table_name, date_range_part_col_name, master_ext_table_name;
    BEGIN
        script_text := 'DROP TABLE IF EXISTS gpm.' || master_ext_table_name;
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;

        script_text := 'CREATE TABLE gpm.' || master_ext_table_name || ' AS '
                    || 'SELECT * FROM gpm.' || master_table_name;
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;
    END;


    --  7. Starting from the earliest quarter(based on least createddate in mnadvsimulation__c table) till current quarter,
    --     - create child tables of mnadvsimulationoutput__c master table.
    --     - create PK, Unique Key constraints
    --     - create appropriate indexes
    --     - create INSERT RULEs for each child table created
    RAISE INFO 'Start creation of child tables.';
    BEGIN
        -- Determine start year/quarter
        RAISE INFO 'Determine start year/quarter.';
        script_text := 'SELECT createddate FROM gpm.' || sim_table_name || ' ORDER BY createddate LIMIT 1';
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text INTO min_createddate;
        start_year := EXTRACT(YEAR FROM min_createddate);
        start_quarter := EXTRACT(QUARTER FROM min_createddate);
        RAISE INFO '%', start_year || ' Q' || start_quarter;

        -- Determine end year/quarter
        RAISE INFO 'Determine end year/quarter.';
        curr_year := extract(year FROM now());
        curr_quarter := extract(quarter FROM now());
        RAISE INFO '%', curr_year || ' Q' || curr_quarter;

        RAISE INFO 'Creating child tables starting from year & quarter : %', start_year || ' Q' || start_quarter;
        WHILE (start_year * 10 + start_quarter) <= (curr_year * 10 + curr_quarter) LOOP
            partition_start_date = TO_CHAR(TO_DATE(start_year || '-' || (((start_quarter - 1) * 3) + 1) || '-1', 'YYYY-MM-DD'), 'YYYY-MM-DD');
            partition_next_start_date = TO_CHAR(partition_start_date + interval '3 months', 'YYYY-MM-DD');

            check_constraint_text := date_range_part_col_name || ' >= TO_DATE(''' || partition_start_date || ''', ''YYYY-MM-DD'') '
                                  || 'AND ' || date_range_part_col_name || ' < TO_DATE(''' || partition_next_start_date || ''', ''YYYY-MM-DD'')';

            -- Create child table
            child_table_name := master_table_name || '_' || start_year || 'q' || start_quarter;
            RAISE INFO 'Creating child table';
            script_text := 'CREATE TABLE gpm.' || child_table_name || '('
                        || 'CONSTRAINT ' || child_table_name || '_pkey PRIMARY KEY (id)'
                        -- Check Constraint
                        || ', CONSTRAINT ' || child_table_name || '_ck CHECK ('
                        || check_constraint_text
                        || ')'
                        || ') INHERITS (gpm.' || master_table_name || ');';
            RAISE INFO 'Script: %', script_text;
            EXECUTE script_text;

            -- Create INSERT Rule
            RAISE INFO 'Creating INSERT Rule';
            script_text := 'CREATE RULE ' || child_table_name || '_insert AS '
                        || 'ON INSERT TO gpm.' || master_table_name || ' WHERE ('
                        || check_constraint_text
                        || ') '
                        || 'DO INSTEAD '
                        || 'INSERT INTO gpm.' || child_table_name || ' VALUES (NEW.*)';
            RAISE INFO 'Script: %', script_text;
            EXECUTE script_text;

            -- Create indexes
            RAISE INFO 'Creating indexes';
            child_table_name_for_index := sf_namespace || master_table_short_name || '_' || start_year || 'q' || start_quarter;
            RAISE INFO 'Creating Index - %', 'idx_' || child_table_name_for_index || '_sim_countryorder_cpsku_cpt ON ' || child_table_name
                                            || '(' || sim_table_fk_name || ',' || sf_namespace || 'countryorder__c,'
                                            || sf_namespace || 'mncountryproductsku__c,' || sf_namespace || 'mncountrypricetype__c)';
            PERFORM gpm.create_index_if_not_exists(
                'btree',
                child_table_name,
                sim_table_fk_name || ','
                || sf_namespace || 'countryorder__c,'
                || sf_namespace || 'mncountryproductsku__c,'
                || sf_namespace || 'mncountrypricetype__c',
                'idx_' || child_table_name_for_index || '_sim_countryorder_cpsku_cpt'
            );
            RAISE INFO 'Creating Index - %', 'idx_' || child_table_name_for_index || '_forecastdate_sim ON ' || child_table_name
                                               || '(' || sf_namespace || 'forecastdate__c,' || sim_table_fk_name || ')';
            PERFORM gpm.create_index_if_not_exists(
                'btree',
                child_table_name,
                sf_namespace || 'forecastdate__c,'
                || sim_table_fk_name,
                'idx_' || child_table_name_for_index || '_forecastdate_sim'
            );
            RAISE INFO 'Creating Index - %', 'idx_' || child_table_name_for_index || '_partkey ON ' || child_table_name
                                            || '(' || sf_namespace || date_range_part_col_name || ')';
            PERFORM gpm.create_index_if_not_exists(
                'btree',
                child_table_name,
                sf_namespace || date_range_part_col_name,
                'idx_' || child_table_name_for_index || '_partkey'
            );

            -- Increment Quarter
            start_quarter := start_quarter + 1;
            IF start_quarter > 4 THEN
                start_year := start_year + 1;
                start_quarter := 1;
            END IF;
        END LOOP;

        RAISE INFO 'Child tables created till year & quarter : %', curr_year || ' Q' || curr_quarter;
    END;

    --  8. TRUNCATE mnadvsimulationoutput__c table.
    RAISE INFO 'Deleting all records from %', master_table_name;
    BEGIN
        script_text := 'TRUNCATE TABLE gpm.' || master_table_name;
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;
    END;

    --  9. Copy all records from from mnadvsimulationoutput__c_ext to mnadvsimulationoutput__c table.
    --     With the INSERT RULEs in place, records will flow into appropriate child table.
    RAISE INFO 'Copying backed up data from % to %', master_ext_table_name, master_table_name;
    BEGIN
        script_text := 'INSERT INTO gpm.' || master_table_name || ' SELECT * FROM gpm.' || master_ext_table_name;
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text;
    END;

    -- 10. Verify that there are zero records in 'ONLY mnadvsimulationoutput__c' table.
    RAISE INFO 'Running Verification...';
    BEGIN
        script_text := 'SELECT COUNT(*) FROM ONLY gpm.' || master_table_name;
        RAISE INFO 'Script: %', script_text;
        EXECUTE script_text INTO row_count;
        IF row_count > 0 THEN
            RAISE EXCEPTION 'After paritioning, table % should not contain any records. Please re-verify the data/script before proceeding again.', master_table_name;
        END IF;
    END;

    RAISE INFO 'END OF PARTITION_MNADVSIMULATIONOUTPUT';

    RAISE EXCEPTION 'Force Rollback';
END;
$PARTITION_MNADVSIMULATIONOUTPUT$ LANGUAGE plpgsql;