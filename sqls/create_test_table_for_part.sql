DO $$
DECLARE
    sf_namespace VARCHAR := '';
    master_table_name VARCHAR := sf_namespace || 'mnadvsimulationoutput__c';
    test_table_name VARCHAR := master_table_name || '_testmnirp';
    script_text VARCHAR;
    tab_name VARCHAR;
    row_count INTEGER;
BEGIN
    RAISE NOTICE '%: START', timeofday();

    -- Drop test tables if exists
    script_text := 'DROP TABLE IF EXISTS gpm.' || test_table_name || ' CASCADE';
    RAISE NOTICE '%: %', timeofday(), script_text;
    EXECUTE script_text;
    script_text := 'SELECT table_name FROM information_schema.tables WHERE table_schema = ''gpm'' AND table_name LIKE ''' || test_table_name || '%''';
    RAISE NOTICE '%: %', timeofday(), script_text;
    FOR tab_name IN EXECUTE script_text
        LOOP
            script_text := 'DROP TABLE gpm.' || tab_name || ' CASCADE';
            RAISE NOTICE '%', script_text;
            EXECUTE script_text;
        END LOOP;

    -- Create test tables
    script_text := 'CREATE table gpm.' || test_table_name || ' as '
                || 'SELECT * FROM gpm.' || master_table_name;
    RAISE NOTICE '%: %', timeofday(), script_text;
    EXECUTE script_text;

    -- Count rows
    script_text := 'SELECT COUNT(*) FROM gpm.' || test_table_name;
    RAISE NOTICE '%: %', timeofday(), script_text;
    EXECUTE script_text INTO row_count;
    RAISE NOTICE '%: %', timeofday(), row_count;

    -- Create indexes
    script_text := 'CREATE INDEX idx_mnadvsimoutputtest_forecastdate_sim '
                || 'ON gpm.' || test_table_name || ' USING btree '
                || '(' || sf_namespace || 'forecastdate__c, ' || sf_namespace || 'mnadvsimulation__c)';
    RAISE NOTICE '%: %', timeofday(), script_text;
    EXECUTE script_text;

    script_text := 'CREATE INDEX idx_mnadvsimoutputtest_sim_countryorder_cpsku_cpt '
                || 'ON gpm.' || test_table_name || ' USING btree '
                || '(' || sf_namespace || 'mnadvsimulation__c, ' || sf_namespace || 'countryorder__c, ' || sf_namespace || 'mncountryproductsku__c, ' || sf_namespace || 'mncountrypricetype__c)';
    RAISE NOTICE '%: %', timeofday(), script_text;
    EXECUTE script_text;

    RAISE NOTICE '%: FINISH', timeofday();
END;
$$ LANGUAGE plpgsql;