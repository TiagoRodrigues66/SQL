/*============================================================================

  Authors:  m20201748, Daniela Didier
			m20201833 Pedro Dias
			m20201771, Tiago Rodrigues
			m20201730, Tânia Canas

  ============================================================================*/
--Select database
USE AdventureWorks
GO

-- Set-up the results message of the Transact-SQL statements 
PRINT '' 
PRINT 'Development start date - ' + CONVERT(varchar, GETDATE(), 113);

SET NOCOUNT ON; -- Stops the message that shows the count of the number of rows affected by a Transact-SQL statement 
--or stored procedure from being returned as part of the result set.


/*SELECT * from Auction.FinancialImpact*/

--Check if auctioned products are being sold below on average less than 70% of standard cost
GO
CREATE OR ALTER VIEW Auction.FinancialImpact

AS

		SELECT  max_bid_average_4.ProductSubcategoryID , 
		AVG(max_bid_average_4.MaxBid) AS AverageSellPrice , 
		AVG(max_bid_average_4.StandardCost) AS AverageStandardCost,
		AVG(max_bid_average_4.MaxBid)/AVG(max_bid_average_4.StandardCost) as Margin,
		
		CASE
		WHEN AVG(max_bid_average_4.MaxBid) > 0.7 * AVG(max_bid_average_4.StandardCost) 
		THEN 'Positive'
		
		ELSE 'Negative'
		END AS Financial_Impact

		FROM 
		(
			SELECT * FROM
					(
					SELECT max_bid_average_2.* , PP.ProductSubcategoryID , PP.StandardCost

						FROM
						(
						SELECT max_bid_average .*, AP.ProductID

								FROM
								(
								SELECT AP.AuctionID , MAX(ABid.BidAmmount) AS MaxBid

									FROM AUCTION.BidPlacement AS ABid

									LEFT JOIN
									Auction.ProductID as AP
									ON AP.AuctionID = ABid.AuctionID

									WHERE AP.AuctionStatusId = 0 AND StatusDescription = 'Ended'
									GROUP BY AP.AuctionID
							
								)
								AS max_bid_average
								LEFT JOIN Auction.ProductID as AP
								ON max_bid_average.AuctionID = AP.AuctionID
							)
							AS max_bid_average_2
							LEFT JOIN Production.Product  as PP
							ON  PP.ProductID = max_bid_average_2.ProductID
						)
						AS max_bid_average_3
					)
					AS max_bid_average_4
				GROUP BY  max_bid_average_4.ProductSubcategoryID
			
GO


--update order date at salesorder : year 2014 to 2021


/*ALTER TABLE sales.SalesOrderHeader
DROP Constraint CK_SalesOrderHeader_DueDate
ALTER TABLE sales.SalesOrderHeader
DROP Constraint CK_SalesOrderHeader_ShipDate

GO

update sales.SalesOrderHeader
set OrderDate  = dateadd(year, (2021 - year(OrderDate)), OrderDate)
where year(OrderDate) = 2014

GO*/
---
--Get insights insight how much sales from auction represents while compared with total sales.
/*SELECT * from Auction.AuctionVSSales*/
CREATE OR ALTER VIEW Auction.AuctionVSSales
AS

select  m4.ProductSubcategoryID,m4.StoreSalesSum, m4.AuctionSalesSum from
(
select * from
(

	SELECT sub1.ProductSubcategoryID, SUM(sub1.LineTotal) as StoreSalesSum
	from
							   
			(
			SELECT SOD.SalesOrderID, SOH.OrderDate, SOD.ProductID, SOD.LineTotal, SOD.OrderQty,PP.ProductSubcategoryID


			FROM Sales.SalesOrderHeader as SOH
			INNER JOIN SALES.SalesOrderDetail AS SOD

			ON SOH.SalesOrderID = SOD.SalesOrderID

			INNER JOIN Production.Product  as PP
			ON SOD.ProductID = PP.ProductID
			WHERE year(OrderDate) = 2021
			)
			AS sub1
		GROUP BY ProductSubcategoryID
		)
	AS sub2
	

		INNER JOIN
		(
		

		select m2.* from
		(
		select SUM(sub3.MaxBid) as AuctionSalesSum ,sub3.ProductSubcategoryID as Sub
		from(
		SELECT sub4.* , PP.ProductSubcategoryID 

		FROM
		(
		SELECT max_bid_average .*, AP.ProductID

				FROM
				(
				SELECT AP.AuctionID , MAX(ABid.BidAmmount) AS MaxBid

					FROM AUCTION.BidPlacement AS ABid

					INNER JOIN
					Auction.ProductID as AP
					ON AP.AuctionID = ABid.AuctionID

					WHERE AP.AuctionStatusId = 0 AND StatusDescription = 'Ended'  and year(AP.StartDate) = 2021
					GROUP BY AP.AuctionID
							
						)
						AS max_bid_average
						INNER JOIN Auction.ProductID as AP
						ON max_bid_average.AuctionID = AP.AuctionID
					)
					AS sub4
					INNER JOIN Production.Product  as PP
					ON  PP.ProductID = sub4.ProductID
							
				) as sub3
				group by ProductSubcategoryID
					) as m2
				
			) as m3
			on sub2.ProductSubcategoryID = m3.Sub

	) as m4
				
				 

GO








	
					
					
			