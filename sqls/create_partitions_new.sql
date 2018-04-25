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
--  1. Pause INSERT/DELETE on mnadvsimulation__c table.
--  2. Verify that all records in mnadvsimulation__c has a createddate.
--  3. Create a backup of mnadvsimulationoutput__c table.
--     Name the new table like this - mnadvsimulationoutput__c_bak_<current_datetime>.
--  4. Create a new table (without data) from mnadvsimulationoutput__c table.
--  5. Add column mnadvsimcreateddate__c to mnadvsimulationoutput__c_new to capture the simulation scenario creation date.
--     This new column will act as the partition key for the quarterly range partition.
--  6. Starting from the earliest quarter(based on least createddate in mnadvsimulation__c table) till current quarter,
--     - create child tables of mnadvsimulationoutput__c_new master table.
--     - create PK constraint
--     - create appropriate indexes
--     - insert appropriate rows into the child table
--  7. Verify partitioned data integrity
--  8. Create INSERT rules and CHECK constraints.
--  9. Rename tables so that mnadvsimulation__c_new becomes mnadvsimulation__c
-- 10. Turn on constraint_exclusion.
-- 11. Resume INSERT/DELETE on mnadvsimulation__c table.
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
    master_table_name VARCHAR := sf_namespace || 'mnadvsimulationoutput__c__testmnirp';
    master_table_part_col_name VARCHAR := 'createddate';
    new_master_table_name VARCHAR := master_table_name || '_new';
    master_table_short_name VARCHAR := 'mnadvsimoutput';
    date_range_part_col_name VARCHAR := sf_namespace || 'mnadvsimcreateddate__c';
    check_constraint_text VARCHAR;
    part_data_sel_date_constraint_text VARCHAR;
    child_table_name VARCHAR;
    child_table_name_for_index VARCHAR;
    script_text VARCHAR;
    source_row_count INTEGER;
    row_count INTEGER;
BEGIN

    IF LENGTH(sf_namespace) = 0 THEN
        RAISE INFO '%: namespace not specified', now();
    ELSE
        RAISE INFO '%: namespace: %', now(), sf_namespace;
    END IF;


    --  1. Pause INSERT/DELETE on mnadvsimulation__c table.
    RAISE INFO '%: Pausing INSERT/DELETE on %', now(), master_table_name;
    script_text := 'CREATE RULE ' || master_table_name || '_insert_disable AS ON INSERT TO gpm.' || master_table_name || ' DO INSTEAD NOTHING';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    script_text := 'CREATE RULE ' || master_table_name || '_delete_disable AS ON DELETE TO gpm.' || master_table_name || ' DO INSTEAD NOTHING';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    
    
    --  2. Verify that all records in mnadvsimulation__c has a createddate.
    RAISE INFO '%: Verifying data in %...', now(), sim_table_name;
    script_text := 'SELECT COUNT(*) FROM gpm.' || sim_table_name || ' WHERE createddate IS NULL';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text INTO row_count;
    RAISE INFO '%: %', now(), row_count;
    IF row_count > 0 THEN
        RAISE EXCEPTION '%: % rows in % have NULL createddate. Please re-verify/clean up the data before proceeding again.', now(), row_count, sim_table_name;
    END IF;
    
    
    --  3. Create a backup of mnadvsimulationoutput__c table.
    --     Name the new table like this - mnadvsimulationoutput__c_bak_<current_datetime>.
    RAISE INFO '%: Creating backup of %', now(), master_table_name;
    script_text := 'CREATE TABLE gpm.' || master_table_name || '_bak_' || TO_CHAR(now(), 'YYYYMMDDHH24MISS') || ' AS '
                || 'SELECT * FROM gpm.' || master_table_name;
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    
    
    --  4. Create a new table (without data) from mnadvsimulationoutput__c table.
    RAISE INFO '%: Creating a structural copy of %', now(), master_table_name;
    script_text := 'CREATE TABLE gpm.' || new_master_table_name
                || '(LIKE gpm.' || master_table_name || ')';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    
    
    --  5. Add column mnadvsimcreateddate__c to mnadvsimulationoutput__c_new to capture the simulation scenario creation date.
    --     This new column will act as the partition key for the quarterly range partition.
    RAISE INFO '%: Adding column % to %', now(), date_range_part_col_name, new_master_table_name;
    script_text := 'ALTER TABLE gpm.' || new_master_table_name || ' '
                || 'ADD COLUMN ' || date_range_part_col_name || ' timestamp without time zone';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    
    
    --  6. Starting from the earliest quarter(based on least createddate in mnadvsimulation__c table) till current quarter,
    --     - create child tables of mnadvsimulationoutput__c_new master table.
    --     - create PK constraint
    --     - create appropriate indexes
    --     - insert appropriate rows into the child table
    RAISE INFO '%: Start creation of child tables.', now();
    -- Determine start year/quarter
    RAISE INFO '%: Determine start year/quarter.', now();
    script_text := 'SELECT createddate FROM gpm.' || sim_table_name || ' ORDER BY createddate LIMIT 1';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text INTO min_createddate;
    start_year := EXTRACT(YEAR FROM min_createddate);
    start_quarter := EXTRACT(QUARTER FROM min_createddate);
    RAISE INFO '%: %', now(), start_year || ' Q' || start_quarter;

    -- Determine end year/quarter
    RAISE INFO '%: Determine end year/quarter.', now();
    curr_year := extract(year FROM now());
    curr_quarter := extract(quarter FROM now());
    RAISE INFO '%: %', now(), curr_year || ' Q' || curr_quarter;

    RAISE INFO '%: Creating child tables starting from year & quarter : %', now(), start_year || ' Q' || start_quarter;
    WHILE (start_year * 10 + start_quarter) <= (curr_year * 10 + curr_quarter) LOOP
        partition_start_date = TO_CHAR(TO_DATE(start_year || '-' || (((start_quarter - 1) * 3) + 1) || '-1', 'YYYY-MM-DD'), 'YYYY-MM-DD');
        partition_next_start_date = TO_CHAR(partition_start_date + interval '3 months', 'YYYY-MM-DD');

        check_constraint_text := date_range_part_col_name || ' >= TO_DATE(''' || partition_start_date || ''', ''YYYY-MM-DD'') '
                              || 'AND ' || date_range_part_col_name || ' < TO_DATE(''' || partition_next_start_date || ''', ''YYYY-MM-DD'')';

        -- Create child table
        child_table_name := master_table_name || '_' || start_year || 'q' || start_quarter;
        RAISE INFO '%: Creating child table', now();
        script_text := 'CREATE TABLE gpm.' || child_table_name || '('
                    -- PK Constraint
                    || 'CONSTRAINT ' || child_table_name || '_pkey PRIMARY KEY (id)'
                    || ') INHERITS (gpm.' || new_master_table_name || ');';
        RAISE INFO '%: %', now(), script_text;
        EXECUTE script_text;

        -- Create indexes
        RAISE INFO '%: Creating indexes', now();
        child_table_name_for_index := sf_namespace || master_table_short_name || '_' || start_year || 'q' || start_quarter;
        RAISE INFO '%: Creating Index - %', now(), 'idx_' || child_table_name_for_index || '_sim_countryorder_cpsku_cpt ON ' || child_table_name
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
        RAISE INFO '%: Creating Index - %', now(), 'idx_' || child_table_name_for_index || '_forecastdate_sim ON ' || child_table_name
                                           || '(' || sf_namespace || 'forecastdate__c,' || sim_table_fk_name || ')';
        PERFORM gpm.create_index_if_not_exists(
            'btree',
            child_table_name,
            sf_namespace || 'forecastdate__c,'
            || sim_table_fk_name,
            'idx_' || child_table_name_for_index || '_forecastdate_sim'
        );
        RAISE INFO '%: Creating Index - %', now(), 'idx_' || child_table_name_for_index || '_partkey ON ' || child_table_name
                                        || '(' || sf_namespace || date_range_part_col_name || ')';
        PERFORM gpm.create_index_if_not_exists(
            'btree',
            child_table_name,
            sf_namespace || date_range_part_col_name,
            'idx_' || child_table_name_for_index || '_partkey'
        );

        -- Insert rows
        RAISE INFO '%: Inserting rows into child table', now();
        part_data_sel_date_constraint_text := 'asim.' || master_table_part_col_name || ' >= TO_DATE(''' || partition_start_date || ''', ''YYYY-MM-DD'') '
                              || 'AND ' || 'asim.' || master_table_part_col_name || ' < TO_DATE(''' || partition_next_start_date || ''', ''YYYY-MM-DD'')';
        script_text := 'INSERT INTO gpm.' || child_table_name || ' '
                    || 'SELECT aso.*, asim.createddate AS ' || date_range_part_col_name || ' '
                    || 'FROM gpm.' || master_table_name || ' aso '
                    || 'INNER JOIN gpm.' || sim_table_name || ' asim ON aso.' || sim_table_fk_name || ' = asim.sfid '
                    || 'WHERE ' || part_data_sel_date_constraint_text;
        RAISE INFO '%: %', now(), script_text;
        EXECUTE script_text;

        -- Increment Quarter
        start_quarter := start_quarter + 1;
        IF start_quarter > 4 THEN
            start_year := start_year + 1;
            start_quarter := 1;
        END IF;
    END LOOP;

    RAISE INFO '%: Child tables created till year & quarter : %', now(), curr_year || ' Q' || curr_quarter;
    
    
    --  7. Verify partitioned data integrity
    RAISE INFO '%: Running Verification...', now();
    script_text := 'SELECT COUNT(1) '
                || 'FROM gpm.' || master_table_name || ' aso '
                || 'INNER JOIN gpm.' || sim_table_name || ' asim ON aso.' || sim_table_fk_name || ' = asim.sfid';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text INTO source_row_count;
    RAISE INFO '%: %', now(), source_row_count;
    script_text := 'SELECT COUNT(1) '
                || 'FROM gpm.' || new_master_table_name;
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text INTO row_count;
    RAISE INFO '%: %', now(), row_count;
    IF row_count != source_row_count THEN
        RAISE EXCEPTION '%: Row count mis-match after partitioning.', now();
    END IF;
    script_text := 'SELECT COUNT(*) FROM ONLY gpm.' || new_master_table_name;
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text INTO row_count;
    RAISE INFO '%: %', now(), row_count;
    IF row_count > 0 THEN
        RAISE EXCEPTION '%: After paritioning, table % should not contain any records.', new_master_table_name;
    END IF;
    
    
    --  8. Create INSERT rules and CHECK constraints.
    RAISE INFO '%: Creating INSERT Rules and Check constraints.', now();
    -- Reset variables for re-iteration
    start_year := EXTRACT(YEAR FROM min_createddate);
    start_quarter := EXTRACT(QUARTER FROM min_createddate);
    WHILE (start_year * 10 + start_quarter) <= (curr_year * 10 + curr_quarter) LOOP
        partition_start_date = TO_CHAR(TO_DATE(start_year || '-' || (((start_quarter - 1) * 3) + 1) || '-1', 'YYYY-MM-DD'), 'YYYY-MM-DD');
        partition_next_start_date = TO_CHAR(partition_start_date + interval '3 months', 'YYYY-MM-DD');
        child_table_name := master_table_name || '_' || start_year || 'q' || start_quarter;
        check_constraint_text := date_range_part_col_name || ' >= TO_DATE(''' || partition_start_date || ''', ''YYYY-MM-DD'') '
                              || 'AND ' || date_range_part_col_name || ' < TO_DATE(''' || partition_next_start_date || ''', ''YYYY-MM-DD'')';

        -- Add CHECK constraint
        script_text := 'ALTER TABLE gpm.' || child_table_name || ' '
                    || 'ADD CONSTRAINT ' || child_table_name || '_ck CHECK ('
                    || check_constraint_text
                    || ')';
        RAISE INFO '%: %', now(), script_text;
        EXECUTE script_text;

        -- Create INSERT Rule
        script_text := 'CREATE RULE ' || child_table_name || '_insert AS '
                    || 'ON INSERT TO gpm.' || new_master_table_name || ' WHERE ('
                    || check_constraint_text
                    || ') '
                    || 'DO INSTEAD '
                    || 'INSERT INTO gpm.' || child_table_name || ' VALUES (NEW.*)';
        RAISE INFO '%: %', now(), script_text;
        EXECUTE script_text;

        -- Increment Quarter
        start_quarter := start_quarter + 1;
        IF start_quarter > 4 THEN
            start_year := start_year + 1;
            start_quarter := 1;
        END IF;
    END LOOP;
    
    
    --  9. Rename tables so that mnadvsimulation__c_new becomes mnadvsimulation__c
    RAISE INFO '%: Renaming tables.', now();
    script_text := 'ALTER TABLE gpm.' || master_table_name || ' RENAME TO ' || master_table_name || '_old';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    script_text := 'ALTER TABLE gpm.' || new_master_table_name || ' RENAME TO ' || master_table_name;
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    
    
    -- 10. Turn on constraint_exclusion.
    RAISE INFO '%: Turning on constraint exclusion', now();
    SET constraint_exclusion = on; 
    
    
    -- 11. Resume INSERT/DELETE on mnadvsimulation__c table.
    RAISE INFO '%: Resuming INSERT/DELETE on %', now(), master_table_name;
    script_text := 'DROP RULE ' || master_table_name || '_insert_disable ON gpm.' || master_table_name || '_old';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    script_text := 'DROP RULE ' || master_table_name || '_delete_disable ON gpm.' || master_table_name || '_old';
    RAISE INFO '%: %', now(), script_text;
    EXECUTE script_text;
    
    RAISE INFO '%: END OF PARTITION_MNADVSIMULATIONOUTPUT', now();

    RAISE EXCEPTION '%: Force Rollback', now();
END;
$PARTITION_MNADVSIMULATIONOUTPUT$ LANGUAGE plpgsql;