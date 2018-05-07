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

-- CREATE TABLE IF NOT EXISTS gpm.mnadvsimulationoutput__c_bak AS
-- SELECT * FROM gpm.mnadvsimulationoutput__c

-- SELECT COUNT(1) FROM gpm.mnadvsimulationoutput__c_bak;
-- 2152

-- SELECT
--   asvf.*
-- FROM
--   gpm.mnadvsimvolumeforecast__c asvf
-- WHERE
--   asvf.mnadvsimulation__c = 'a0P3700000CEpDtEAL'
-- ORDER BY
--   asvf.forecastdate__c
  
-- DELETE  
-- FROM
--   gpm.mnadvsimvolumeforecast__c asvf
-- WHERE
--   asvf.id IN (10273, 10272, 10271, 10270)

SELECT 
  country.name,
  productsku.name,
  countrypricetype.channelpricetype__c,
  simulation_output.forecastdate__c,
  simulation_output.baselinerevenue__c,
  simulation_output.irpimpact__c,
  simulation_output.revenueafterimpact__c,
  simulation_output.revenueafterimpactpercent__c,
  simulation_output.baselinenetrevenue__c,
  simulation_output.netirpimpact__c,
  simulation_output.netrevenueafterimpact__c,
  simulation_output.netrevenueafterimpactpercent__c,
  simulation_output.volume__c,
  simulation_output.price__c,
  simulation_output.listprice__c
FROM 
  gpm.mnadvsimulationoutput__c simulation_output, 
  gpm.mncountryproductsku__c countryproductsku, 
  gpm.mncountrypricetype__c countrypricetype, 
  gpm.mnproductsku__c productsku, 
  gpm.mnproduct__c product, 
  gpm.mncountry__c country 
WHERE 
  simulation_output.mnadvsimulation__c = 'a0P3700000CEpDtEAL'
  AND simulation_output.mncountryproductsku__c = countryproductsku.sfid 
  AND simulation_output.mncountrypricetype__c = countrypricetype.sfid 
  AND simulation_output.mncountry__c = country.sfid 
  AND countryproductsku.mnproductsku__c = productsku.sfid 
  AND productsku.mnproduct__c = product.sfid 
  AND simulation_output.listpricetype__c = true
ORDER BY
  simulation_output.countryorder__c NULLS LAST,
  country.name NULLS LAST,
  product.name NULLS LAST,
  productsku.name NULLS LAST,
  productsku.strength__c NULLS LAST,
  productsku.packsize__c NULLS LAST,
  productsku.formulation__c NULLS LAST,
  productsku.vialsize__c NULLS LAST,
  countrypricetype.channelpricetype__c NULLS LAST,
  simulation_output.uom__c NULLS LAST,
  simulation_output.forecastdate__c NULLS LAST
LIMIT 325

SELECT
  asim.name, asim.status__c, asim.errormessage__c
FROM
  gpm.mnadvsimulation__c asim
ORDER BY
  asim.lastmodifieddate DESC








