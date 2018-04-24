-- select sfid, name, mnirp__startdate__c, mnirp__enddate__c from gpm.mnirp__mnadvsimulation__c order by createddate desc
-- "a0W1k000000H85nEAC" "BE PRICE CUT -5%_Copy"

SELECT 
  country.name,
  productsku.name,
  countrypricetype.mnirp__channelpricetype__c,
  simulation_output.mnirp__forecastdate__c,
  simulation_output.mnirp__baselinerevenue__c,
  simulation_output.mnirp__irpimpact__c,
  simulation_output.mnirp__revenueafterimpact__c,
  simulation_output.mnirp__revenueafterimpactpercent__c,
  simulation_output.mnirp__baselinenetrevenue__c,
  simulation_output.mnirp__netirpimpact__c,
  simulation_output.mnirp__netrevenueafterimpact__c,
  simulation_output.mnirp__netrevenueafterimpactpercent__c,
  simulation_output.mnirp__volume__c,
  simulation_output.mnirp__price__c,
  simulation_output.mnirp__listprice__c
FROM 
  gpm.mnirp__mnadvsimulationoutput__c simulation_output, 
  gpm.mnirp__mncountryproductsku__c countryproductsku, 
  gpm.mnirp__mncountrypricetype__c countrypricetype, 
  gpm.mnirp__mnproductsku__c productsku, 
  gpm.mnirp__mnproduct__c product, 
  gpm.mnirp__mncountry__c country 
WHERE 
  simulation_output.mnirp__mnadvsimulation__c = 'a0W1k000000H85nEAC' 
  AND simulation_output.mnirp__mncountryproductsku__c = countryproductsku.sfid 
  AND simulation_output.mnirp__mncountrypricetype__c = countrypricetype.sfid 
  AND simulation_output.mnirp__mncountry__c = country.sfid 
  AND countryproductsku.mnirp__mnproductsku__c = productsku.sfid 
  AND productsku.mnirp__mnproduct__c = product.sfid 
  AND simulation_output.mnirp__listpricetype__c = true
  AND simulation_output.mnirp__forecastdate__c = '2018-04-16'
ORDER BY
  simulation_output.mnirp__countryorder__c NULLS LAST,
  country.name NULLS LAST,
  product.name NULLS LAST,
  productsku.name NULLS LAST,
  productsku.mnirp__strength__c NULLS LAST,
  productsku.mnirp__packsize__c NULLS LAST,
  productsku.mnirp__formulation__c NULLS LAST,
  productsku.mnirp__vialsize__c NULLS LAST,
  countrypricetype.mnirp__channelpricetype__c NULLS LAST,
  simulation_output.mnirp__uom__c NULLS LAST,
  simulation_output.mnirp__forecastdate__c NULLS LAST
LIMIT 5*36

SELECT 
  country.name,
--   productsku.name,
--   countrypricetype.mnirp__channelpricetype__c,
--   simulation_output.mnirp__forecastdate__c,
  simulation_output.mnirp__baselinerevenue__c,
  simulation_output.mnirp__irpimpact__c,
  simulation_output.mnirp__revenueafterimpact__c,
  simulation_output.mnirp__revenueafterimpactpercent__c,
  simulation_output.mnirp__baselinenetrevenue__c,
  simulation_output.mnirp__netirpimpact__c,
  simulation_output.mnirp__netrevenueafterimpact__c,
  simulation_output.mnirp__netrevenueafterimpactpercent__c,
  simulation_output.mnirp__volume__c,
  simulation_output.mnirp__price__c,
  simulation_output.mnirp__listprice__c
FROM 
  gpm.mnirp__mnadvsimulationoutput__c simulation_output, 
  gpm.mnirp__mncountryproductsku__c countryproductsku, 
  gpm.mnirp__mncountrypricetype__c countrypricetype, 
  gpm.mnirp__mnproductsku__c productsku, 
  gpm.mnirp__mnproduct__c product, 
  gpm.mnirp__mncountry__c country, 
  gpm.mnirp__mnpricetype__c pricetype 
WHERE 
  simulation_output.mnirp__mnadvsimulation__c = 'a0W1k000000H85nEAC' 
  AND simulation_output.mnirp__mncountryproductsku__c = countryproductsku.sfid 
  AND simulation_output.mnirp__mncountrypricetype__c = countrypricetype.sfid 
  AND simulation_output.mnirp__mncountry__c = country.sfid 
  AND countryproductsku.mnirp__mnproductsku__c = productsku.sfid 
  AND productsku.mnirp__mnproduct__c = product.sfid 
  AND countrypricetype.mnirp__mnpricetype__c = pricetype.sfid 
  AND simulation_output.mnirp__listpricetype__c = true 
  AND simulation_output.mnirp__forecastdate__c = '2018-04-16'
ORDER BY 
  simulation_output.mnirp__countryorder__c NULLS LAST, 
  country.name NULLS LAST, 
  product.name NULLS LAST, 
  productsku.name NULLS LAST, 
  productsku.mnirp__strength__c NULLS LAST, 
  productsku.mnirp__packsize__c NULLS LAST, 
  productsku.mnirp__formulation__c NULLS LAST, 
  productsku.mnirp__vialsize__c NULLS LAST, 
  countrypricetype.mnirp__channelpricetype__c NULLS LAST, 
  simulation_output.mnirp__uom__c NULLS LAST, 
  simulation_output.mnirp__forecastdate__c NULLS LAST 
LIMIT 
  1800
