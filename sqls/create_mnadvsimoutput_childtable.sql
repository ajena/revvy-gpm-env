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


CREATE OR REPLACE FUNCTION gpm.create_mnadvsimoutput_childtable_if_not_exists() RETURNS void AS $$
DECLARE
    -- MUST READ: If the SFDC Org has namespace, you must specify it with ALL lowercase and double underscores, for example: 'gpmnightly__'
    sf_namespace VARCHAR := '';

    schema_name VARCHAR := 'gpm';
    curr_year INTEGER := extract(year FROM now());
    curr_quarter INTEGER := extract(quarter FROM now());
    partition_start_date DATE;
    partition_next_start_date DATE;
    sim_table_name VARCHAR := sf_namespace || 'mnadvsimulation__c';
    sim_table_fk_name VARCHAR := sf_namespace || 'mnadvsimulation__c';
    master_table_name VARCHAR := sf_namespace || 'mnadvsimulationoutput__c';
    master_table_part_col_name VARCHAR := 'createddate';
    master_table_short_name VARCHAR := 'mnadvsimoutput';
    date_range_part_col_name VARCHAR := sf_namespace || 'mnadvsimcreateddate__c';
    constraint_text_format VARCHAR := '%s >= DATE ''%s'' AND %s < DATE ''%s''';
    check_constraint_text VARCHAR;
    part_data_sel_date_constraint_text VARCHAR;
    child_table_name VARCHAR;
    child_table_name_for_index VARCHAR;
    script_text VARCHAR;
BEGIN

    -- FOR TESTING
    curr_quarter := curr_quarter + 1;
    child_table_name := master_table_name || '_' || curr_year || 'q' || curr_quarter;

    IF NOT EXISTS (
        SELECT 1
        FROM   information_schema.tables tab
        WHERE  tab.table_schema = schema_name
        AND    tab.table_name = child_table_name
    ) THEN

        partition_start_date = start_year || '-' || (((start_quarter - 1) * 3) + 1) || '-1';
        partition_next_start_date = TO_CHAR(partition_start_date + interval '3 months', 'YYYY-MM-DD');
        check_constraint_text := FORMAT(constraint_text_format, date_range_part_col_name, partition_start_date, date_range_part_col_name, partition_next_start_date);

        -- Create child table (with Check constraints)
        RAISE NOTICE '%: Creating child table %',  timeofday(), child_table_name;
        script_text := 'CREATE TABLE gpm.' || child_table_name || '('
                    || 'CONSTRAINT ' || child_table_name || '_ck CHECK('
                    || check_constraint_text || ')'
                    || ') INHERITS (gpm.' || master_table_name || ')';
        RAISE NOTICE '%: %', timeofday(), script_text;
        EXECUTE script_text;

        -- Create indexes
        RAISE NOTICE '%: Creating indexes', timeofday();
        child_table_name_for_index := sf_namespace || master_table_short_name || '_' || curr_year || 'q' || curr_quarter;
        RAISE NOTICE '%: Creating Index - %', timeofday(), 'idx_' || child_table_name_for_index || '_sim_countryorder_cpsku_cpt ON ' || child_table_name
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
        RAISE NOTICE '%: Creating Index - %', timeofday(), 'idx_' || child_table_name_for_index || '_forecastdate_sim ON ' || child_table_name
                                           || '(' || sf_namespace || 'forecastdate__c,' || sim_table_fk_name || ')';
        PERFORM gpm.create_index_if_not_exists(
            'btree',
            child_table_name,
            sf_namespace || 'forecastdate__c,'
            || sim_table_fk_name,
            'idx_' || child_table_name_for_index || '_forecastdate_sim'
        );

        -- Create INSERT Rule
        RAISE NOTICE '%: Creating INSERT rule.', timeofday();
        script_text := 'CREATE RULE ' || child_table_name || '_insert AS '
                    || 'ON INSERT TO gpm.' || master_table_name || ' WHERE ('
                    || check_constraint_text
                    || ') '
                    || 'DO INSTEAD '
                    || 'INSERT INTO gpm.' || child_table_name || ' VALUES (NEW.*)';
        RAISE NOTICE '%: %', timeofday(), script_text;
        EXECUTE script_text;

    ELSE
        RAISE NOTICE '%: Skip creation. Child table % exists.',  timeofday(), child_table_name;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '%: Error creating %, Error: %, SQL state: %.', timeofday(), child_table_name, SQLERRM, SQLSTATE;
END;
$$ LANGUAGE plpgsql;

-- DO $$
-- BEGIN
--     PERFORM gpm.create_mnadvsimoutput_childtable_if_not_exists();
-- END
-- $$ LANGUAGE plpgsql;
