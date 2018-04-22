-- SELECT COUNT(1) FROM gpm.mnadvsimulationoutput__c;
-- 2,152

-- SELECT to_char(asim.createddate, 'YYYYQ'), COUNT(aso.id)
-- FROM   gpm.mnadvsimulationoutput__c aso
--        , gpm.mnadvsimulation__c asim
-- WHERE  aso.mnadvsimulation__c = asim.sfid
-- GROUP BY to_char(asim.createddate, 'YYYYQ')
-- ORDER BY to_char(asim.createddate, 'YYYYQ');
-- "20174"	 "302"
-- "20181"	"1498"
-- "20182"	 "352"

-- DROP TABLE gpm.mnadvsimulationoutputpart__c
-- CREATE TABLE gpm.mnadvsimulationoutputpart__c
-- (LIKE gpm.mnadvsimulationoutput__c INCLUDING DEFAULTS);

-- INSERT INTO gpm.mnadvsimulationoutputpart__c
-- SELECT * FROM gpm.mnadvsimulationoutput__c;
-- 399 msec

-- ALTER TABLE gpm.mnadvsimulationoutputpart__c
-- ADD COLUMN simulation_createddate timestamp without time zone;

-- UPDATE gpm.mnadvsimulationoutputpart__c aso
-- SET simulation_createddate = asim.createddate
-- FROM gpm.mnadvsimulation__c asim
-- WHERE aso.mnadvsimulation__c = asim.sfid;
-- 382 msec

-- SELECT to_char(aso.simulation_createddate, 'YYYYQ'), COUNT(aso.id)
-- FROM   gpm.mnadvsimulationoutputpart__c aso
-- GROUP BY to_char(aso.simulation_createddate, 'YYYYQ');
-- "20174"	 "302"
-- "20171"	 "352"
-- "20172"	"1498"

-- SELECT COUNT(*) FROM gpm.mnadvsimulationoutput__c 
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );
-- 23891

-- SELECT COUNT(*) FROM gpm.mnadvsimulationoutputpart__c 
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );
-- 23891

-- DELETE FROM gpm.mnadvsimulationoutputpart__c 
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );

-- DELETE FROM gpm.mnadvsimulationoutput__c 
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );

-- SELECT COUNT(*) FROM gpm.mnadvsimulationcountrysummary__c
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );
-- 2317

-- DELETE FROM gpm.mnadvsimulationcountrysummary__c
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );

-- SELECT COUNT(*) FROM gpm.mnadvsimulationcountryimpact__c
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );
-- 36

-- DELETE FROM gpm.mnadvsimulationcountryimpact__c
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );

-- SELECT asim.createddate 
-- FROM gpm.mnadvsimulation__c asim
-- ORDER BY asim.createddate LIMIT 1;
-- 2016-06-28 21:33:08


-- DO $ADVSIM_INDEX_CREATION$
-- DECLARE
--     sf_namespace VARCHAR := '';
-- BEGIN

-- PERFORM gpm.create_index_if_not_exists('btree', sf_namespace || 'mnadvsimulationcountryimpact__c', sf_namespace || 'mnadvsimulation__c,' || sf_namespace || 'mncountry__c', 'idx_mnadvsimulationcountryimpact_sim_country');
-- PERFORM gpm.create_index_if_not_exists('btree', sf_namespace || 'mnadvsimulationcountrysummary__c', sf_namespace || 'mnadvsimulation__c,' || sf_namespace || 'mncountry__c', 'idx_mnadvsimulationcountrysummary_sim_country');
-- PERFORM gpm.create_index_if_not_exists('btree', sf_namespace || 'mnadvsimulationcountrysummary__c', sf_namespace || 'forecastdate__c,' || sf_namespace || 'mnadvsimulation__c', 'idx_mnadvsimulationcountrysummary_forecastdate_sim');
-- PERFORM gpm.create_index_if_not_exists('btree', sf_namespace || 'mnadvsimulationoutput__c', sf_namespace || 'mnadvsimulation__c,' || sf_namespace || 'countryorder__c,' || sf_namespace || 'mncountryproductsku__c,' || sf_namespace || 'mncountrypricetype__c', 'idx_mnadvsimoutput_sim_countryorder_cpsku_cpt');
-- PERFORM gpm.create_index_if_not_exists('btree', sf_namespace || 'mnadvsimulationoutput__c', sf_namespace || 'forecastdate__c,' || sf_namespace || 'mnadvsimulation__c', 'idx_mnadvsimoutput_forecastdate_sim');

-- END;
-- $ADVSIM_INDEX_CREATION$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS gpm.mnadvsimulationoutput__c_bak AS
SELECT * FROM gpm.mnadvsimulationoutput__c

SELECT COUNT(1) FROM gpm.mnadvsimulationoutput__c_bak;
2152













