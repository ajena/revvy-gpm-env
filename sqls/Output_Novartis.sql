select count(1) from gpm.mnirp__mnadvsimulationoutput__c
-- 41,123,711

select mnirp__mnadvsimulation__c, count(1) from gpm.mnirp__mnadvsimulationoutput__c
group by mnirp__mnadvsimulation__c
order by count(1) desc
-- "a0X24000003gLIOEA2"	"1235304"
-- "a0X24000003gUBuEAM"	"1235304"
-- "a0X24000009g3dtEAA"	"792060"
-- "a0X240000071IQ7EAM"	"565212"
-- "a0X24000008UbjFEAS"	"549171"
-- "a0X24000008PONBEA4"	"518320"
-- "a0X1o000009u5qWEAQ"	"488628"

select mnirp__mnadvsimulation__c, count(1) from gpm.mnirp__mnadvsimulationoutput__c 
where mnirp__listpricetype__c = True
and mnirp__mnadvsimulation__c IN (
    'a0X24000003gLIOEA2', 'a0X24000003gUBuEAM', 'a0X24000009g3dtEAA', 'a0X240000071IQ7EAM', 'a0X24000008UbjFEAS', 'a0X24000008PONBEA4', 'a0X1o000009u5qWEAQ'
)
group by mnirp__mnadvsimulation__c
order by count(1) desc

select c.name, mnirp__channelpricetype__c
from gpm.mnirp__mncountrypricetype__c cpt
inner join gpm.mnirp__mncountry__c c on cpt.mnirp__mncountry__c = c.sfid
where mnirp__grosspricetype__c = True
order by c.name