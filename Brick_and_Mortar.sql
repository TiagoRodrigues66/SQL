/*============================================================================

  Authors:  m20201748, Daniela Didier
			m20201833 Pedro Dias
			m20201771, Tiago Rodrigues
			m20201730, Tânia Canas

  ============================================================================*/
use AdventureWorks
go

--select states with more sells
select SUM(m2.SUBTOTAL) AS SUM_TOTAL, m2.State  
	from (
			SELECT m1.* , P_ADRESS.city as City , P_STATE.name as State 
				from (
					  select  StoreID, sc.CustomerID AS CustID, SUM(SOH.SubTotal) AS SUBTOTAL 
					  from sales.customer as SC

					  left join sales.SalesTerritory as ST
					  on SC.TerritoryID = ST.TerritoryID
  
					  left join sales.SalesOrderHeader as SOH
					  on SOH.CustomerID = sc.CustomerID 
  

					  WHERE CountryRegionCode = 'US' and StoreID is not null and subtotal is not null
					  GROUP BY sc.CustomerID ,StoreID
					   ) as m1
					  left join person.BusinessEntityAddress as Bus_adress
					  ON Bus_adress.BusinessEntityID = m1.StoreID
  
					  left join person.Address  as P_ADRESS
					  on P_ADRESS.AddressID = Bus_adress.AddressID

					  left join person.StateProvince  as P_STATE
					  on P_ADRESS.StateProvinceID= P_STATE.StateProvinceID
  

  where bus_adress.AddressTypeID = 3

 
  ) as m2
group by state
   ORDER BY SUM_TOTAL DESC
   

--select stores with more sales
   SELECT m1.* , ss.name as Store_Name , P_ADRESS.city as City , P_STATE.name as State , P_ADRESS.PostalCode
   from (

			  select  StoreID, sc.CustomerID AS CustID, SUM(SOH.SubTotal) AS SUBTOTAL 
			  from sales.customer as SC

			  left join sales.SalesTerritory as ST
			  on SC.TerritoryID = ST.TerritoryID
  
			  left join sales.SalesOrderHeader as SOH
			  on SOH.CustomerID = sc.CustomerID 
  

			  WHERE CountryRegionCode = 'US' and StoreID is not null and subtotal is not null
			  GROUP BY sc.CustomerID ,StoreID
				) as m1

  left join person.BusinessEntityAddress as Bus_adress
  ON Bus_adress.BusinessEntityID = m1.StoreID
  
  left join person.Address  as P_ADRESS
  on P_ADRESS.AddressID = Bus_adress.AddressID

  left join person.StateProvince  as P_STATE
  on P_ADRESS.StateProvinceID= P_STATE.StateProvinceID
  
  left join Sales.Store as SS
  on Bus_adress.BusinessEntityID = ss.BusinessEntityID

  WHERE bus_adress.AddressTypeID = 3
  ORDER BY SUBTOTAL DESC