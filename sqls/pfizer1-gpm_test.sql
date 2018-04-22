-- SELECT createddate from gpm.mnadvsimulation__c where name = 'Limit GR 60 A'
-- "2016-10-24 20:16:49"

-- CREATE TABLE gpm.mnadvsimulationoutput__c_2016Q4 AS
-- SELECT * FROM gpm.mnadvsimulationoutput__c WITH NO DATA

-- ALTER TABLE gpm.mnadvsimulationoutput__c_2016Q4
--     ADD CONSTRAINT mnadvsimulationoutput__c_2016Q4_pkey PRIMARY KEY (id);

-- CREATE INDEX idx_mnadvsimoutput_2016Q4_forecastdate_sim
--     ON gpm.mnadvsimulationoutput__c_2016Q4 USING btree
--     (forecastdate__c, mnadvsimulation__c);
    
-- CREATE INDEX idx_mnadvsimoutput_2016Q4_sim_countryorder_cpsku_cpt
--     ON gpm.mnadvsimulationoutput__c_2016Q4 USING btree
--     (mnadvsimulation__c, countryorder__c, mncountryproductsku__c, mncountrypricetype__c);

-- INSERT INTO gpm.mnadvsimulationoutput__c_2016Q4
-- SELECT aso.* 
-- FROM gpm.mnadvsimulationoutput__c aso 
-- INNER JOIN gpm.mnadvsimulation__c asim 
--     ON aso.mnadvsimulation__c = asim.sfid
--     AND asim.createddate >= '2016-10-01'
--     AND asim.createddate < '2017-01-01' -- Scenarios created in 2016 Q4
-- Inserted 4482815 in 5 min.

-- VACUUM ANALYZE gpm.mnadvsimulationoutput__c;
-- VACUUM ANALYZE gpm.mnadvsimulationoutput__c_2016Q4;

SELECT 
  simulation_output.sfid, 
  simulation_output.name, 
  simulation_output.currencyisocode, 
  simulation_output.mnadvsimulation__c, 
  simulation_output.mncountry__c, 
  simulation_output.countryorder__c, 
  simulation_output.mncountryproductsku__c, 
  simulation_output.mncountrypricetype__c, 
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
  simulation_output.uom__c, 
  countrypricetype.sfid countrypricetype_sfid, 
  countrypricetype.name countrypricetype_name, 
  countrypricetype.currencyisocode countrypricetype_currencyisocode, 
  countrypricetype.MnChannel__c countrypricetype_mnchannel__c, 
  countrypricetype.ChannelName__c countrypricetype_channelname__c, 
  countrypricetype.MnPriceType__c countrypricetype_mnpricetype__c, 
  countrypricetype.PriceTypeName__c countrypricetype_pricetypename__c, 
  countrypricetype.ChannelPriceType__c countrypricetype_channelpricetype__c, 
  productsku.sfid productsku_sfid, 
  productsku.name productsku_name, 
  productsku.currencyisocode productsku_currencyisocode, 
  productsku.MnProduct__c productsku_mnproduct__c, 
  productsku.Strength__c productsku_strength__c, 
  productsku.Formulation__c productsku_formulation__c, 
  productsku.PackSize__c productsku_packsize__c, 
  productsku.VialSize__c productsku_vialsize__c, 
  product.sfid product_sfid, 
  product.name product_name, 
  product.currencyisocode product_currencyisocode, 
  country.sfid country_sfid, 
  country.name country_name, 
  country.currencyisocode country_currencyisocode, 
  country.ISOCode__c country_isocode__c 
FROM 
--   gpm.mnadvsimulationoutput__c simulation_output, 
  gpm.mnadvsimulationoutput__c_2016Q4 simulation_output, 
  gpm.mncountryproductsku__c countryproductsku, 
  gpm.mncountrypricetype__c countrypricetype, 
  gpm.mnproductsku__c productsku, 
  gpm.mnproduct__c product, 
  gpm.mncountry__c country, 
  gpm.mnpricetype__c pricetype 
WHERE 
  simulation_output.mnadvsimulation__c = 'a0W36000003IOfTEAW' 
  AND simulation_output.mncountryproductsku__c = countryproductsku.sfid 
  AND simulation_output.mncountrypricetype__c = countrypricetype.sfid 
  AND simulation_output.mncountry__c = country.sfid 
  AND countryproductsku.mnproductsku__c = productsku.sfid 
  AND productsku.mnproduct__c = product.sfid 
  AND countrypricetype.mnpricetype__c = pricetype.sfid 
  AND simulation_output.listpricetype__c = true 
  AND simulation_output.countryorder__c IN (1, 2, 3) 
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
LIMIT 
  3000
