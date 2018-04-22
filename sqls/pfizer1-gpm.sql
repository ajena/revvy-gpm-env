-- SELECT COUNT(1) FROM gpm.mnadvsimulationoutput__c;
-- 29,007,196

-- SELECT to_char(asim.createddate, 'YYYYQ'), COUNT(aso.id)
-- FROM   gpm.mnadvsimulationoutput__c aso
--        , gpm.mnadvsimulation__c asim
-- WHERE  aso.mnadvsimulation__c = asim.sfid
-- GROUP BY to_char(asim.createddate, 'YYYYQ');
-- "20162"	"299674"
-- "20163"	"20238676"
-- "20164"	"4482815"
-- "20171"	"2526254"
-- "20172"	"552"
-- "20173"	"1363910"
-- "20174"	"22820"

-- DROP TABLE gpm.mnadvsimulationoutputpart__c
-- CREATE TABLE gpm.mnadvsimulationoutputpart__c
-- (LIKE gpm.mnadvsimulationoutput__c INCLUDING DEFAULTS);

-- INSERT INTO gpm.mnadvsimulationoutputpart__c
-- SELECT * FROM gpm.mnadvsimulationoutput__c;
-- 5 mins

-- ALTER TABLE gpm.mnadvsimulationoutputpart__c
-- ADD COLUMN simulation_createddate timestamp without time zone;

-- UPDATE gpm.mnadvsimulationoutputpart__c aso
-- SET simulation_createddate = asim.createddate
-- FROM gpm.mnadvsimulation__c asim
-- WHERE aso.mnadvsimulation__c = asim.sfid;
-- 8 mins

-- SELECT to_char(aso.simulation_createddate, 'YYYYQ'), COUNT(aso.id)
-- FROM   gpm.mnadvsimulationoutputpart__c aso
-- GROUP BY to_char(aso.simulation_createddate, 'YYYYQ');
-- "20162"	"299674"
-- "20163"	"20238676"
-- "20164"	"4482815"
-- "20171"	"2526254"
-- "20172"	"552"
-- "20173"	"1363910"
-- "20174"	"22820"

-- SELECT COUNT(*) FROM gpm.mnadvsimulationoutput__c 
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );
-- 72495

-- SELECT COUNT(*) FROM gpm.mnadvsimulationoutputpart__c 
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );
-- 72495

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
-- 775

-- DELETE FROM gpm.mnadvsimulationcountrysummary__c
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );

-- SELECT COUNT(*) FROM gpm.mnadvsimulationcountryimpact__c
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );
-- 62

-- DELETE FROM gpm.mnadvsimulationcountryimpact__c
-- WHERE mnadvsimulation__c NOT IN (
--     SELECT sfid FROM gpm.mnadvsimulation__c
-- );

-- SELECT asim.createddate 
-- FROM gpm.mnadvsimulation__c asim
-- ORDER BY asim.createddate LIMIT 1;
-- 2016-06-28 21:33:08