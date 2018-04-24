CREATE OR REPLACE FUNCTION gpm.add_column_if_not_exists (sf_namespace text, tbl_name text, col_name text, col_type text) RETURNS void AS $$
DECLARE
    schema_name VARCHAR;
BEGIN
    schema_name = 'gpm';
    IF NOT EXISTS (SELECT column_name FROM information_schema.columns WHERE table_schema=schema_name AND table_name = sf_namespace || tbl_name and column_name = sf_namespace||col_name) THEN
        EXECUTE 'ALTER TABLE '|| schema_name||'.'|| sf_namespace || tbl_name || ' ADD COLUMN ' || sf_namespace ||  col_name || ' ' || col_type;
    ELSE
        RAISE NOTICE '% %.% % column exists.', sf_namespace, tbl_name, sf_namespace, col_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

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
--  1. Disable INSERT/DELETE on mnadvsimulationoutput__c table.
--  2. Create a backup of mnadvsimulationoutput__c table. Name the new table like this - mnadvsimulationoutput__c_bak_<current_datetime>.
--  3. Delete the orphan (where the corresponding mnadvsimulation__c record doesn't exist anymore) records from mnadvsimulationoutput__c.
--  4. Add column mnadvsimcreateddate__c to mnadvsimulationoutput__c to capture the simulation scenario creation date. 
--     This new column will act as the partition key for the quarterly range partition.
--  5. Update this column with appropriate value by joining mnadvsimulation__c table.
--  6. At this point create another backup table mnadvsimulationoutput__c_ext from mnadvsimulationoutput__c. 
--     We'll use this new table as the source table to insert records into mnadvsimulationoutput__c after creating partitions and INSERT rules.
--  7. TRUNCATE mnadvsimulationoutput__c table.
--  8. Starting from the earliest quarter(based on least createddate in mnadvsimulation__c table) till current quarter,
--     - create child tables of mnadvsimulationoutput__c master table.
--     - create PK, Unique Key constraints
--     - create appropriate indexes
--     - create INSERT RULEs for each child table created
--  9. Now copy everything from mnadvsimulationoutput__c_ext to mnadvsimulationoutput__c table.
-- 10. Verify that there are zero records in 'ONLY mnadvsimulationoutput__c' table.
-- 11. DROP all constraints and indexes from mnadvsimulationoutput__c table.
-- 12. Re-enable INSERT/DELETE on mnadvsimulationoutput__c table.
-- 13. At any point, if there are any errors, then revert to original state by following actions
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
    master_table_name VARCHAR := sf_namespace || 'mnadvsimulationoutput__c';
    master_table_short_name VARCHAR := 'mnadvsimoutput';
    date_range_part_col_name VARCHAR := sf_namespace || 'mnadvsimcreateddate__c';
    child_table_name VARCHAR;
    child_table_name_for_index VARCHAR;
    script_text VARCHAR;
BEGIN

	IF LENGTH(sf_namespace) = 0 THEN
		RAISE NOTICE 'namespace not specified';
	ELSE
		RAISE NOTICE 'namespace: %', sf_namespace;
	END IF;

	--  1. Disable INSERT/DELETE on mnadvsimulationoutput__c table.
	RAISE NOTICE 'TODO : Disabling INSERT/DELETE on %', master_table_name;
	BEGIN
		-- EXECUTE 'CREATE RULE ' || master_table_name || '_disable_insert AS ON INSERT TO gpm.' || master_table_name || ' DO INSTEAD NOTHING';
		-- EXECUTE 'CREATE RULE ' || master_table_name || '_disable_delete AS ON DELETE TO gpm.' || master_table_name || ' DO INSTEAD NOTHING';
	END;
	
	--  2. Create a backup of mnadvsimulationoutput__c table. 
    --     Name the new table like this - mnadvsimulationoutput__c_bak_<current_datetime>.
	RAISE NOTICE 'Creating backup of %', master_table_name;
	BEGIN
		script_text := 'CREATE TABLE gpm.' || master_table_name || '_bak_' || TO_CHAR(now(), 'YYYYMMDDHH24MISS') || ' AS '
					|| 'SELECT * FROM gpm.' || master_table_name;
		RAISE NOTICE 'Script: %', script_text;
		EXECUTE script_text;
	END;
    
    --  3. Delete the orphan (where the corresponding mnadvsimulation__c record doesn't exist anymore) records from mnadvsimulationoutput__c.
    RAISE NOTICE 'Deleting orphan records from %', master_table_name;
    BEGIN
        script_text := 'DELETE FROM gpm.' || master_table_name || ' '
                    || 'WHERE ' || sf_namespace || 'mnadvsimulation__c NOT IN ('
                    || 'SELECT sfid FROM gpm.' || sf_namespace || 'mnadvsimulation__c'
                    || ')';
        RAISE NOTICE 'Script: %', script_text;
		EXECUTE script_text;            
    END;
	
    --  4. Add column mnadvsimcreateddate__c to mnadvsimulationoutput__c to capture the simulation scenario creation date. 
    --     This new column will act as the partition key for the quarterly range partition.
	RAISE NOTICE 'Adding column % to %', date_range_part_col_name, master_table_name;
    BEGIN
	    script_text := 'ALTER TABLE gpm.' || master_table_name || ' '
	                || 'ADD COLUMN ' || date_range_part_col_name || ' timestamp without time zone';
        RAISE NOTICE 'Script: %', script_text;
	    EXECUTE script_text;
	END;
    
    --  5. Update this column with appropriate value by joining mnadvsimulation__c table.
	RAISE NOTICE 'Updating column %', date_range_part_col_name;
    BEGIN
        script_text := 'UPDATE gpm.' || master_table_name || ' aso '
	                || 'SET ' || date_range_part_col_name || ' = asim.createddate '
	                || 'FROM gpm.' || sf_namespace || 'mnadvsimulation__c asim '
	                || 'WHERE aso.' || sf_namespace || 'mnadvsimulation__c = asim.sfid';
        RAISE NOTICE 'Script: %', script_text;
	    EXECUTE script_text;
	END;
         
	-- RAISE NOTICE 'Create a copy of this new table with simulation_createddate column';
	-- EXECUTE ' DROP TABLE IF EXISTS gpm.' || master_table_name || '_ext';
	-- EXECUTE ' CREATE TABLE gpm.' || master_table_name || '_ext AS '
	--      || ' SELECT * FROM gpm.' || master_table_name;
		 
	-- RAISE NOTICE 'Delete all record from mnadvsimulationoutput__c table. After creation of child tables and insert rule/trigger, we''ll populate records using backed up from mnadvsimulationtoutput_ext table';
	-- EXECUTE 'TRUNCATE TABLE gpm.' || master_table_name;

	-- RAISE NOTICE 'Creation of child tables';

	-- -- Determine start year/quarter
	-- EXECUTE 'SELECT createddate FROM gpm.' || sf_namespace || 'mnadvsimulation__c ORDER BY createddate LIMIT 1' INTO min_createddate;
	-- start_year := EXTRACT(YEAR FROM min_createddate);
	-- start_quarter := EXTRACT(QUARTER FROM min_createddate);
	-- RAISE NOTICE 'Creating partitions starting from year & quarter : %', start_year || ' Q' || start_quarter;
	-- -- Determine end year/quarter
	-- curr_year := extract(year FROM now());
	-- curr_quarter := extract(quarter FROM now());

	-- WHILE (start_year * 10 + start_quarter) <= (curr_year * 10 + curr_quarter) LOOP
	--     partition_start_date = TO_CHAR(TO_DATE(start_year || '-' || (((start_quarter - 1) * 3) + 1) || '-1', 'YYYY-MM-DD'), 'YYYY-MM-DD');
	--     partition_next_start_date = TO_CHAR(partition_start_date + interval '3 months', 'YYYY-MM-DD');
	--     -- Create Child Tables
	--     child_table_name := master_table_name || '_' || start_year * 10 + start_quarter;    
	--     RAISE NOTICE 'Creating Child Table - %', 'gpm.' || child_table_name;
	--     EXECUTE 'CREATE TABLE IF NOT EXISTS gpm.' || child_table_name || '('
	--         || 'CONSTRAINT ' || child_table_name || '_pkey PRIMARY KEY (id)'
	--         -- Check Constraint
	--         || ', CONSTRAINT ' || child_table_name || '_ck CHECK ( '
	--             || 'simulation_createddate >= TO_DATE(''' || partition_start_date || ''', ''YYYY-MM-DD'') '
	--             || 'AND simulation_createddate < TO_DATE(''' || partition_next_start_date || ''', ''YYYY-MM-DD'')'
	--             || ' )'
	--         || ') INHERITS (gpm.' || master_table_name || ');';
	--     -- Create INSERT Rule
	--     EXECUTE ' CREATE RULE ' || child_table_name || '_insert AS '
	--     || ' ON INSERT TO gpm.' || master_table_name || ' WHERE ('
	--     || '     simulation_createddate >= TO_DATE(''' || partition_start_date || ''', ''YYYY-MM-DD'') '
	--     || '     AND simulation_createddate < TO_DATE(''' || partition_next_start_date || ''', ''YYYY-MM-DD'')'
	--     || ' ) '
	--     || ' DO INSTEAD '
	--     || ' INSERT INTO gpm.' || child_table_name || ' VALUES (NEW.*) ';
	--     -- Create indexes
	--     child_table_name_for_index := sf_namespace || master_table_short_name || '_' || start_year * 10 + start_quarter;
	--     RAISE NOTICE 'Creating Index - %', 'idx_' || child_table_name_for_index || '_sim_countryorder_cpsku_cpt ON ' || child_table_name || '(' || sf_namespace || 'mnadvsimulation__c,' || sf_namespace || 'countryorder__c,' || sf_namespace || 'mncountryproductsku__c,' || sf_namespace || 'mncountrypricetype__c)';
	--     PERFORM gpm.create_index_if_not_exists(
	--         'btree', 
	--         child_table_name, 
	--         sf_namespace || 'mnadvsimulation__c,' 
	--             || sf_namespace || 'countryorder__c,' 
	--             || sf_namespace || 'mncountryproductsku__c,' 
	--             || sf_namespace || 'mncountrypricetype__c', 
	--         'idx_' || child_table_name_for_index || '_sim_countryorder_cpsku_cpt'
	--     );
	--     RAISE NOTICE 'Creating Index - %', 'idx_' || child_table_name_for_index || '_forecastdate_sim ON ' || child_table_name || '(' || sf_namespace || 'forecastdate__c,' || sf_namespace || 'mnadvsimulation__c)';
	--     PERFORM gpm.create_index_if_not_exists(
	--         'btree', 
	--         child_table_name, 
	--         sf_namespace || 'forecastdate__c,' 
	--             || sf_namespace || 'mnadvsimulation__c', 
	--         'idx_' || child_table_name_for_index || '_forecastdate_sim'
	--     );
	--     RAISE NOTICE 'Creating Index - %', 'idx_' || child_table_name_for_index || '_partkey ON ' || child_table_name || '(' || sf_namespace || date_range_part_col_name || ')';
	--     PERFORM gpm.create_index_if_not_exists(
	--         'btree', 
	--         child_table_name, 
	--         sf_namespace || date_range_part_col_name, 
	--         'idx_' || child_table_name_for_index || '_partkey'
	--     );
		
	--     -- Increment Quarter
	--     start_quarter := start_quarter + 1;
	--     IF start_quarter > 4 THEN
	--         start_year := start_year + 1;
	--         start_quarter := 1;
	--     END IF;
	-- END LOOP;

	-- RAISE NOTICE 'Partitions created till year & quarter : %', curr_year || ' ' || curr_quarter;

	-- RAISE NOTICE 'Copy backed up data'
	-- EXECUTE 'INSERT INTO gpm.' || master_table_name || ' SELECT * FROM gpm.' || master_table_name || '_ext';

	--  1. Re-enable INSERT/DELETE on mnadvsimulationoutput__c table.
	RAISE NOTICE 'TODO : Enabling INSERT/DELETE on %', master_table_name;

	RAISE NOTICE 'END OF PARTITION_MNADVSIMULATIONOUTPUT';
END;
$PARTITION_MNADVSIMULATIONOUTPUT$ LANGUAGE plpgsql;

-- insert into gpm.mnadvsimulationoutput__c select * from gpm.mnadvsimulationoutput__c_ext
-- select count(*) from gpm.mnadvsimulationoutput__c_ext
-- select count(*) from gpm.mnadvsimulationoutput__c
-- DELETE from ONLY gpm.mnadvsimulationoutput__c
-- COMMIT
-- select count(*) from ONLY gpm.mnadvsimulationoutput__c
-- select count(*) from gpm.mnadvsimulationoutput__c_20174
-- select count(*) from gpm.mnadvsimulationoutput__c_20181
-- select count(*) from gpm.mnadvsimulationoutput__c_20182

