/*============================================================================

  
  Authors:  m20201748, Daniela Didier
			m20201833 Pedro Dias
			m20201771, Tiago Rodrigues
			m20201730, Tânia Canas

  Summary:  Creates the AdventureWorks auction schema.

  ============================================================================*/
--Select database
USE AdventureWorks
GO

-- Set-up the results message of the Transact-SQL statements 
PRINT '' 
PRINT 'Development start date - ' + CONVERT(varchar, GETDATE(), 113);

SET NOCOUNT ON; -- Stops the message that shows the count of the number of rows affected by a Transact-SQL statement 
--or stored procedure from being returned as part of the result set.

-- Create Auction Schema

IF SCHEMA_ID('Auction') IS NULL
	EXEC('CREATE SCHEMA Auction AUTHORIZATION dbo');
GO

-- Drop tables if exist
-- ******************************************************
/*
IF (OBJECT_ID('Auction.ProductID') IS NOT NULL)
BEGIN 
DROP TABLE Auction.ProductID
END
GO
IF (OBJECT_ID('Auction.BidSettings') IS NOT NULL)
BEGIN 
DROP TABLE Auction.BidSettings
END
GO
IF (OBJECT_ID('Auction.BidPlacement') IS NOT NULL)
BEGIN 
DROP TABLE Auction.BidPlacement
END
GO
*/

-- ******************************************************
-- Create new Tables
-- ******************************************************

IF OBJECT_ID('Auction.ProductID') IS NULL
CREATE TABLE Auction.ProductID(
	AuctionID INT NOT NULL IDENTITY PRIMARY KEY,
   	ProductID INT NOT NULL,
	StartDate DATETIME2 NOT NULL,
	EndDate DATETIME2 NOT NULL,
	AuctionStatusId BIT  NULL,
	InitialBidPrice MONEY NOT NULL,
	InitialListPrice MONEY NOT NULL, 
	StatusDescription varchar(20) null,


) ON [PRIMARY];
GO

IF OBJECT_ID('Auction.BidSettings') IS NULL
CREATE TABLE Auction.BidSettings(
	BidID int IDENTITY (1, 1) NOT NULL,
    MinBidIncrease money NOT NULL,
	MaxBidLimit float NOT NULL,
	InitialBidLocal float NOT NULL,
	InitialBidRetailers float NOT NULL,
	StartBidDate datetime NOT NULL,
	StopBidDate datetime NOT NULL
 CONSTRAINT PK_BidSettings PRIMARY KEY CLUSTERED 
(
	BidID ASC
)
) ON [PRIMARY];
GO

IF OBJECT_ID('Auction.BidPlacement') IS NULL
CREATE TABLE Auction.BidPlacement(

    BidID int IDENTITY (1, 1) NOT NULL,
	AuctionID int NOT NULL,
	ProductID int NOT NULL,
	CustomerID int NOT NULL,
	BidDateTime datetime NOT NULL,
	BidAmmount money NOT NULL
 CONSTRAINT PK_BidPlacement PRIMARY KEY CLUSTERED 
(
	BidID ASC
)
) ON [PRIMARY];
GO

-- Add BitSettings data

IF NOT EXISTS(SELECT * FROM Auction.BidSettings)
	INSERT INTO Auction.BidSettings VALUES ('0.05', '1.0', '0.5', '0.75','2021-11-15T00:00:00','2021-11-28T23:59:59');
GO

-- Add AuctionStatus data

-- ******************************************************
-- Create new Functions
-- ******************************************************

-- Set SellEndDate and DiscountedDate to NULL and Cost > 50$


CREATE OR ALTER FUNCTION Auction.IsCommercializedProduct(@productID int)
RETURNS bit
AS
BEGIN
	DECLARE @CommercializedProduct bit;

	SELECT @ProductID = ProductID
      FROM Production.Product AS Prod
	 WHERE Prod.SellEndDate is NULL
	   AND Prod.DiscontinuedDate IS NULL
	   AND Prod.StandardCost > 50
	   AND Prod.ProductID = @productID;
IF @@ROWCOUNT = 1
		SET @CommercializedProduct = 1;
	ELSE
		SET @CommercializedProduct = 0;

	RETURN @CommercializedProduct;
END;
GO


/* Exclude accessories from the campaing. We needed to join Product with Sub category first and after join this with 
Category to get the column "Name" because the Product table can't directly be related with the Category table */


CREATE OR ALTER FUNCTION Auction.IsProductCategoryOk(@productID int)
RETURNS bit
AS
BEGIN
	DECLARE @ProductCategoryOk bit;

	SELECT @ProductID = ProductID
      FROM Production.Product Prod
     INNER
      JOIN Production.ProductSubcategory ProdSubCat
        ON Prod.ProductSubcategoryID = ProdSubCat.ProductSubcategoryID
     INNER
      JOIN Production.ProductCategory ProdCat
		ON ProdSubCat.ProductCategoryID = ProdCat.ProductCategoryID
	 WHERE  ProdCat.Name <> 'Accessories'
	   AND Prod.ProductID = @productID;

	IF @@ROWCOUNT = 1
		SET @ProductCategoryOk = 1;
	ELSE
		SET @ProductCategoryOk = 0;

	RETURN @ProductCategoryOk;
END;
GO

CREATE OR ALTER FUNCTION Auction.isProductBeingAuctioned(@productID int)
RETURNS int
AS
BEGIN
	DECLARE @AuctionID int;
		
	 SELECT  @productID = ProductID 
	 FROM Auction.ProductID as PROD_ID
	 WHERE ProductID = @productID
	 and PROD_ID.AuctionStatusId = 1
	    
	IF @@ROWCOUNT <> 1
		SET @AuctionID = 0;
		ELSE
		SET @AuctionID = 1;

	RETURN @AuctionID;
END;
GO


-- 
CREATE OR ALTER FUNCTION Auction.InitialBidPrice(@productID int)
RETURNS money
AS
BEGIN
	DECLARE @InitialBidPrice money;
	DECLARE @InitialBidLocal money;
	DECLARE @InitialBidRetailers money;
	DECLARE @MakeFlag Int;
	DECLARE @ListPrice money;
	DECLARE @MaxBidLimit money;

	
	SELECT @InitialBidLocal = InitialBidLocal , @InitialBidRetailers = InitialBidRetailers, @MaxBidlimit = MaxBidlimit
	  FROM Auction.BidSettings;

	IF @@ROWCOUNT <> 1
		SET @InitialBidPrice = -1;
	ELSE
	BEGIN
		SELECT @MakeFlag = MakeFlag, @ListPrice = ListPrice
		  FROM Production.Product
		 WHERE ProductID = @ProductID;


		IF @@ROWCOUNT <> 1
			SET	@InitialBidPrice = -2;
		ELSE
			IF @MakeFlag = 0
				SET @InitialBidPrice = @ListPrice * @InitialBidRetailers;
			ELSE
				SET @InitialBidPrice = @ListPrice * @InitialBidLocal;
	END;
	
    RETURN @InitialBidPrice
	
	END;
GO

/* Test functions : select Auction.InitialBidPrice(867) */

CREATE OR ALTER FUNCTION Auction.MaxBidPrice(@productID int)
RETURNS money
AS
BEGIN
	DECLARE @MaxBidLimit money;
	DECLARE @ListPrice money;
	
	SELECT @MaxBidLimit = MaxBidLimit
	  FROM Auction.BidSettings;

	IF @@ROWCOUNT <> 1
		SET @MaxBidLimit = -1;
	ELSE
	BEGIN
		 SELECT @ListPrice = ListPrice
		 FROM Production.Product
		 WHERE ProductID = @ProductID;

		IF @@ROWCOUNT <> 1
		SET @MaxBidLimit = -2;
	ELSE 
		SET @MaxBidLimit = @ListPrice * @MaxBidLimit

	END;
	RETURN @MaxBidLimit;
	END;
   
GO

/*Test function : select Auction.MaxBidPrice(857)*/


CREATE OR ALTER FUNCTION Auction.DoesProductExists(@productID int)
RETURNS int
AS
BEGIN

DECLARE @ProdId int;

	 SELECT  @ProductID = ProductID
	 FROM Production.Product as PROD_ID
	 WHERE ProductID = @productID
	   
	IF @@ROWCOUNT <> 1
		SET @ProdId = 0;
	ELSE
		SET @ProdId = @ProductID;	
		
	RETURN @ProdId;
END;
GO

/*Test functions : select Auction.DoesProductExists(4)*/


CREATE OR ALTER FUNCTION Auction.DoesInventoryExists(@productID int)
RETURNS int
AS
BEGIN

DECLARE @Quantity_aux int;

	 SELECT  @Quantity_aux = Quantity
	 FROM Production.ProductInventory
	 WHERE ProductID = @productID
	   
	
		
	RETURN @Quantity_aux;
END;
GO

/*Test function : select Auction.DoesInventoryExists(853)*/

CREATE OR ALTER FUNCTION Auction.IsCostumerValid(@CustomerID int)
RETURNS int
AS
BEGIN

DECLARE @CustomerID_aux int;

	 SELECT  @CustomerID_aux = CustomerID
	 FROM Sales.Customer
	 WHERE CustomerID = @CustomerID
	 
	IF @@ROWCOUNT <> 1
		SET @CustomerID_aux = 0;
	
	RETURN @CustomerID_aux;
END;
GO


/********************************************  uspAddProductToAuction   ***********************************************/ 

CREATE OR ALTER PROCEDURE Auction.uspAddProductToAuction (@ProductID int, @ExpireDate datetime2 = NULL,
                                                          @InitialBidPrice money = NULL )
AS

-- Declare variables
DECLARE @CurrentDate datetime2 = GETDATE();
DECLARE @StartDate datetime2 = GETDATE() ;
DECLARE @MaxBidPrice int = NULL;
DECLARE @MinBidPrice int = NULL;
DECLARE @AuctionSTATUS varchar (20);
DECLARE @PromotionStartDate datetime2 ;
DECLARE @PromotionEndDate datetime2 ;



--Store usefull variables 
	SELECT @PromotionStartDate = StartBidDate  , @PromotionEndDate = StopBidDate
		FROM Auction.BidSettings;


BEGIN 

--Check if productID exists	
	if Auction.DoesProductExists(@productID) = 0
	BEGIN
	   DECLARE @errormessage1 VARCHAR(150) = 'Product ID does not exist';
	   THROW 50001, @errormessage1, 0;
     END


--Check if Product can be set to auction based on SellEndDate, DiscontinuedDate and StandardCost
	 	 	
    if Auction.IsCommercializedProduct(@ProductID) = 0 

    BEGIN
	   DECLARE @errormessage2 VARCHAR(150) = 'Error uspAddProductToAuction: The submitted @ProductID is not available for auction.';
	   THROW 50002, @errormessage2, 0;
     END
	 	 
	else if Auction.IsProductCategoryOk(@ProductID) = 0	
	 	BEGIN
			DECLARE @errormessage3 VARCHAR(150) = CONCAT('Error uspAddProductToAuction: The product with the ID ', CONVERT(varchar(10), @ProductID), ' is an acessory and cannot be placed for auction.');
			THROW 50003, @errormessage3, 0;
		 END


		 else if Auction.isProductBeingAuctioned(@ProductID) <> 0
			BEGIN
				DECLARE @errormessage4 VARCHAR(150) = CONCAT('Error uspAddProductToAuction: There is already an auction for the product with the ID ', CONVERT(varchar(10), @ProductID));
				THROW 50004, @errormessage4, 0;
		
			END;

	ELSE
		
		BEGIN


-- 

-- IF auction is created before 15 of November, then , Start Date is overwrited and set to the 15th of November		
			
			IF  @CurrentDate < @PromotionStartDate
			BEGIN
				SET @StartDate = @PromotionStartDate;
		    END

  
-- If ExpireData not specified , auctions ends in one week (startdate + 1week)

BEGIN
	IF @ExpireDate is null
		BEGIN
			SET @ExpireDate =  DATEADD(week,1,@StartDate);
		END
END


-- Check if Expire Date is set before the current date
			IF @ExpireDate < @StartDate
				BEGIN
					DECLARE @errormessage51 VARCHAR(200) = CONCAT('Error uspAddProductToAuction: The ExpireDate must be set to a date after ',CAST(@StartDate AS VARCHAR(20)));
					THROW 50051, @errormessage51, 0;
			    END


--Check if End date is between 15 november and 5 december
			BEGIN
				IF NOT(@ExpireDate BETWEEN @PromotionStartDate AND DATEADD (DAY,7,@PromotionEndDate) )
			
				BEGIN
					DECLARE @errormessage5 VARCHAR(200) = CONCAT('Error uspAddProductToAuction: The ExpireDate can only be placed between ' , CAST(@StartDate AS VARCHAR(20)),' and ',CAST(DATEADD (DAY,7,@PromotionEndDate) AS VARCHAR(20)));
					THROW 50005, @errormessage5, 0;
				END
		    END

	 END 


--Check Min bid values
	SET @MinBidPrice = Auction.InitialBidPrice(@ProductID);
		
		IF  @MinBidPrice = 0
			BEGIN
				DECLARE @errormessage6 VARCHAR(150) = 'Error uspAddProductToAuction: List price is set to zero and it should not be set to auction.';
				THROW 50006, @errormessage6, 0;
			END

		IF  @MinBidPrice = -1
			BEGIN
				DECLARE @errormessage7 VARCHAR(150) = 'Error uspAddProductToAuction: Auction settings for the min bid price missing.';
				THROW 50007, @errormessage7, 0;
			END

		IF  @MinBidPrice = -2
			BEGIN
				DECLARE @errormessage8 VARCHAR(150) = 'Error uspAddProductToAuction: List price not defined.';
				THROW 50008, @errormessage8, 0;
			END
	
--Check max bid values
	SET @MaxBidPrice = Auction.MaxBidPrice(@productID) ;
		
		IF  @MaxBidPrice = 0
			BEGIN
				DECLARE @errormessage9 VARCHAR(150) = 'Error uspAddProductToAuction: List price is set to zero and it should not be set to auction';
				THROW 50009, @errormessage9, 0;
			END

		IF  @MaxBidPrice = -1
			BEGIN
				DECLARE @errormessage10 VARCHAR(150) = 'Error uspAddProductToAuction: Auction settings for the initial bid price missing.';
				THROW 50010, @errormessage10, 0;
			END

		IF  @MaxBidPrice = -2
			BEGIN
				DECLARE @errormessage11 VARCHAR(150) = 'Error uspAddProductToAuction: List price not defined.';
				THROW 50011, @errormessage11, 0;
			END

BEGIN
-- Check if the @InitialBidPrice is lower than the minimum bid price
	IF @InitialBidPrice < @MinBidPrice
	BEGIN
		DECLARE @errormessage12 VARCHAR(150) = CONCAT('Error uspAddProductToAuction : The initial bid price should be greater than ', CAST(@MinBidPrice AS VARCHAR(20)),'.');
		THROW 50012, @errormessage12, 0;
	END

-- Check if the @InitialBidPrice is higher than the maximum allowed
	IF @InitialBidPrice > @MaxBidPrice
		BEGIN
			DECLARE @errormessage13 VARCHAR(150) = CONCAT('Error uspAddProductToAuction : The initial bid price should not exceed ', CAST(@MaxBidPrice AS VARCHAR(20)),'.');
			THROW 50013, @errormessage13, 0;
		END

-- Check if the @InitialBidPrice was defined, if not set it to be equal to the MinBidPrice
	IF @InitialBidPrice is NULL
		BEGIN
			set @InitialBidPrice =  @MinBidPrice
		END

--Check if Product ID is in the inventory
if Auction.DoesInventoryExists(@productID) = 0
	BEGIN
	   DECLARE @errormessage14 VARCHAR(150) = 'Product ID does not exist in the inventory';
	   THROW 50014, @errormessage14, 0;
    END



END 

SET @AuctionSTATUS = 'Open'

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
	BEGIN TRANSACTION
		INSERT INTO Auction.ProductID

			(ProductID , StartDate , EndDate , AuctionStatusID , InitialBidPrice , InitialListPrice ,StatusDescription)
		VALUES
			(@ProductID, @StartDate , @ExpireDate, 1, @InitialBidPrice, @MaxBidPrice,  @AuctionSTATUS )
		

	COMMIT TRANSACTION
END
BEGIN
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END 
GO

 --last  END

/********************************************  uspAddProductToAuction   ***********************************************/ 

/********************************************  uspTryBidProduct   ***********************************************/ 



CREATE OR ALTER PROCEDURE Auction.uspTryBidProduct (@ProductID int, @CustomerID int,
                                                          @BidAmmount money = NULL )
AS

-- Declare variables

	DECLARE @CurrentDate datetime2 = GETDATE();
	DECLARE @MinBidIncrease money;
	DECLARE @StartBidDate datetime2;
	DECLARE @StopBidDate datetime2;
	DECLARE @BidProductID int = NULL;
	DECLARE @AuctionID int;
	DECLARE @AuctionStatus int;
	DECLARE @MinBidValue money;
	DECLARE @MaxBidValue money;
	DECLARE @LastBid money;
	DECLARE @AuctionStatusUpdate int;
	DECLARE @PromotionStartDate datetime2;
	DECLARE @PromotionEndDate datetime2;
	
 

--Store usefull variables 

	SELECT @MinBidIncrease = MinBidIncrease,  @PromotionStartDate = StartBidDate  , @PromotionEndDate = StopBidDate
		FROM Auction.BidSettings;

	SELECT  @AuctionID = AuctionID   , @BidProductID = ProductID, @StartBidDate = StartDate , @AuctionStatus = AuctionStatusID,
	@StopBidDate = EndDate, @MinBidValue = InitialBidPrice ,@MaxBidValue = InitialListPrice
		FROM Auction.ProductID
		WHERE ProductID = @ProductID AND AuctionStatusId = 1


		
BEGIN 



-- Check if the Product is being auctioned
	IF Auction.isProductBeingAuctioned(@ProductID) = 0
			BEGIN
				DECLARE @errormessage15 VARCHAR(150) = 'There is not an available auction for the product selected';
				THROW 50015, @errormessage15, 0;
			END;


-- Check if bid is made after StopBidDate
ELSE
  

	IF @StopBidDate < @CurrentDate
				BEGIN 
					DECLARE @errormessage16 VARCHAR(150) = 'Auction is closed';
					THROW 50016, @errormessage16, 0;
				END;

-- Check if Costumer ID is valid ,
ELSE
	IF Auction.IsCostumerValid(@CustomerID) = 0
		BEGIN
			DECLARE @errormessage17 VARCHAR(150) = CONCAT('Error uspTryBidProduct : ', CAST(@CustomerID AS VARCHAR(15)),' is not a valid Customer');
			THROW 50017, @errormessage17, 0;
		END;



--Check if bid is made between startbiddate and stopbiddate
Else
		IF NOT(@CurrentDate BETWEEN @StartBidDate AND @StopBidDate )
			
				BEGIN
					DECLARE @errormessage5 VARCHAR(200) = CONCAT('Error uspTryBidProduct: Bidding is only available between' , CAST(@StartBidDate AS VARCHAR(20)),' and ',CAST(@StopBidDate AS VARCHAR(20)));
					THROW 50005, @errormessage5, 0;
				END
		    END


BEGIN
-- store the last bid placed

	SELECT @LastBid = BidAmmount
	FROM   (SELECT TOP(1) BidAmmount
			FROM Auction.BidPlacement
			WHERE ProductID = @ProductID AND @AuctionID = AuctionID
			ORDER BY BidAmmount DESC )
		  
	AS LastBidPlaced



--If bid not defined, check last bid and add 5 cents to it

	IF @BidAmmount IS NULL 
		BEGIN
			SET @BidAmmount = COALESCE(@LastBid + @MinBidIncrease,@MinBidValue) ;
		END
		
--Check if bid ammount is smaller than the Minimum aceptable 

	IF @BidAmmount < @MinBidValue
		BEGIN 
			DECLARE @errormessage18 VARCHAR(150) = CONCAT('Bid ammount is lower than the minimum aceptable : ',CAST(@MinBidValue + @MinBidIncrease AS VARCHAR(15)),'.') ;
			THROW 50018, @errormessage18, 0;
		END;

--Check if bid ammount is smaller than the Maximum aceptable 

	IF @BidAmmount > @MaxBidValue 
		BEGIN 
			DECLARE @errormessage19 VARCHAR(150) = CONCAT('Bid ammount is higher than the maximum aceptable : ',CAST(@MaxBidValue AS VARCHAR(15)),'.' );
			THROW 50019, @errormessage19, 0;
		END;

--Check if bid ammount is smaller than the last bid

	IF @BidAmmount < @LastBid
		BEGIN 
			DECLARE @errormessage20 VARCHAR(150) = CONCAT('Bid ammount should be higher than the last bid placed  : ',CAST(@LastBid + @MinBidIncrease AS VARCHAR(15)),'.' );
			THROW 50020, @errormessage20, 0;
		END;


-- Check if bid placed is higher than the minimum bid increase (new bid >= LastBidPlaced + MinBidIncrease)
					
	IF @BidAmmount < @MinBidIncrease + @LastBid
		Begin
			DECLARE @errormessage21 VARCHAR(150) = CONCAT('Bid ammount should be higher than : ',CAST(@LastBid + @MinBidIncrease AS VARCHAR(15)),', to respect the minimum bid increase rule.' );
			THROW 50021, @errormessage21, 0;
		END;


-- Check if the Bid ammount is higher than listprice minus the minimum bid increase, to close auction

	IF   @MaxBidValue-@MinBidIncrease <= @BidAmmount
	
		BEGIN
			SET @AuctionStatusUpdate = 2  
		END

END

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN
	BEGIN TRANSACTION

		INSERT INTO Auction.BidPlacement
			(AuctionID , ProductID , CustomerID , BidDateTime , BidAmmount )
		VALUES
			(@AuctionID, @ProductID, @CustomerID, @CurrentDate, @BidAmmount )
			
-- IF Bid ammount was reached or was higher than the list price minus the 5 cents, lets update the AuctionStatus in Auction.productID
	

		IF   @AuctionStatusUpdate = 2 
			BEGIN
				UPDATE Auction.ProductID
				SET AuctionStatusid = 0 , StatusDescription = 'Ended'
				WHERE ProductID = @ProductID and AuctionStatusId = 1 
			END
	
	COMMIT TRANSACTION
BEGIN
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END 
END

-- last end


GO


/********************************************  uspTryBidProduct   ***********************************************/ 


/********************************************  uspRemoveProductFromAuction  ***********************************************/ 

CREATE OR ALTER PROCEDURE Auction.uspRemoveProductFromAuction (@ProductID int)

AS

BEGIN

-- Check if the Product is being auctioned
	IF Auction.isProductBeingAuctioned(@ProductID) = 0
			BEGIN
				DECLARE @errormessage22 VARCHAR(150) = 'Error uspRemoveProductFromAuction: There is not an available auction for the product selected';
				THROW 50022, @errormessage22, 0;
			END;

END

BEGIN
	BEGIN TRANSACTION

		UPDATE Auction.ProductID
		SET AuctionStatusId = 0, StatusDescription = 'Canceled'
		WHERE ProductID = @ProductID AND AuctionStatusID = 1;

	COMMIT TRANSACTION

BEGIN
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END
END
GO
/********************************************  uspRemoveProductFromAuction  ***********************************************/ 


/*************************************  uspSearchForAuctionBasedOnProductName  ************************************************/ 

CREATE OR ALTER PROCEDURE Auction.uspSearchForAuctionBasedOnProductName
--if startingoffset is null set it to zero, and if numberofrows is null set it to the maximum integer possible in sql :2147483647 

(@Productname VARCHAR (25), @StartingOffSet INT = null, @NumberOfRows INT = null )

AS

BEGIN

IF (@StartingOffSet IS NULL)
   SET @StartingOffSet = '0'
   
IF (@NumberOfRows IS NULL)
   SET @NumberOfRows = '2147483647'

IF len(@Productname) < 3 

BEGIN
	DECLARE @errormessage23 VARCHAR(150) = 'Error uspSearchForAuctionBasedOnProductName: Wildcard searches are not acceptable if wildcard search contains less than 3 characters';
	THROW 50023, @errormessage23, 0;
END;


SELECT	AProductID.ProductID ,
		Name,ProductNumber,Color,Size,SizeUnitMeasureCode,
		WeightUnitMeasureCode,Weight,Style,
		ProductSubcategoryID,ProductModelID, HighestBID.Lastbid ,
		AProductID.StatusDescription as Auctionstatus ,COUNT(*) OVER () as TotalCount
		

FROM Auction.ProductID AS AProductID

LEFT JOIN Production.Product AS PProduct
ON AProductID.ProductID = PProduct.ProductID

LEFT JOIN 

(
SELECT MAX (BidAmmount) AS Lastbid , AuctionID
FROM Auction.BidPlacement
GROUP BY AuctionID
) 
AS HighestBID

ON AProductID.AuctionID = HighestBID.AuctionID


WHERE PProduct.Name LIKE CONCAT ('%' , @Productname , '%')


ORDER BY ProductID


OFFSET @StartingOffSet ROWS
FETCH NEXT @NumberOfRows ROWS ONLY;


END
GO


/*************************************  uspSearchForAuctionBasedOnProductName  ***********************************************/ 



/*************************************  uspListBidsOffersHistory   ***********************************************/ 
CREATE OR ALTER PROCEDURE Auction.uspListBidsOffersHistory 
(@CustomerID int, @StartTime datetime2 NULL, @EndTime datetime2 NULL, @Active bit =1)

AS

BEGIN

--Check if customerID exists
	IF Auction.IsCostumerValid(@CustomerID) = 0
			BEGIN
				DECLARE @errormessage24 VARCHAR(150) = CONCAT('Error uspSearchForAuctionBasedOnProductName : ', CAST(@CustomerID AS VARCHAR(15)),' is not a valid Customer');
				THROW 50024, @errormessage24, 0;
			END;

--Check if Start time is after end time

	IF @EndTime <= @StartTime
			BEGIN
				DECLARE @errormessage25 VARCHAR(150) = 'Error uspSearchForAuctionBasedOnProductName : The End date should be after the start date' ;
				THROW 50025, @errormessage25, 0;
			END

--When @Active = 0
If @Active = 0
	BEGIN

		SELECT	ABID.CustomerID, AProductID.AuctionID, ABID.ProductID , ABID.BidAmmount, HighestBID.Lastbid as HighestBidplaced
		,AProductID.StatusDescription as Auctionstatus ,

		CASE
			WHEN ABID.BidAmmount = HighestBID.Lastbid
			and  AProductID.StatusDescription = 'Ended'			
			THEN 'You won auction'

			WHEN ABID.BidAmmount = HighestBID.Lastbid
			and  AProductID.StatusDescription = 'Open'
			THEN 'You are currently winning the auction'

			WHEN ABID.BidAmmount != HighestBID.Lastbid
			and  AProductID.StatusDescription = 'Ended'
			THEN 'You did not win the auction with this bid'

			WHEN ABID.BidAmmount != HighestBID.Lastbid
			and  AProductID.StatusDescription = 'Open'
			THEN 'You are not the highest bidder'


		ELSE 'Auction Canceled'

		END AS AuctionResult


		FROM Auction.ProductID AS AProductID

		LEFT JOIN Auction.BidPlacement AS ABID
		ON AProductID.AuctionID = ABID.AuctionID

		LEFT JOIN 

		(
		SELECT MAX (BidAmmount) AS Lastbid , AuctionID
		FROM Auction.BidPlacement
		GROUP BY AuctionID
		) 
		AS HighestBID

		ON AProductID.AuctionID = HighestBID.AuctionID

		WHERE CustomerID = @CustomerID
		AND ABID.BidDateTime >= @StartTime
		AND ABID.BidDateTime  <= @EndTime
		ORDER BY AuctionID,BidAmmount
	END

--When @Active = 1
If @Active = 1
	BEGIN

	
		SELECT	ABID.CustomerID, AProductID.AuctionID, ABID.ProductID , ABID.BidAmmount, HighestBID.Lastbid as HighestBidplaced
		,AProductID.StatusDescription as Auctionstatus ,

		CASE
			WHEN ABID.BidAmmount = HighestBID.Lastbid
			and  AProductID.StatusDescription = 'Open'
			THEN 'You are currently winning the auction with this bid'

		ELSE 'Not the highest bid'

		END AS AuctionResult


		FROM Auction.ProductID AS AProductID

		LEFT JOIN Auction.BidPlacement AS ABID
		ON AProductID.AuctionID = ABID.AuctionID

		LEFT JOIN 

		(
		SELECT MAX (BidAmmount) AS Lastbid , AuctionID
		FROM Auction.BidPlacement
		GROUP BY AuctionID
		) 
		AS HighestBID

		ON AProductID.AuctionID = HighestBID.AuctionID

		WHERE CustomerID = @CustomerID
		AND ABID.BidDateTime >= @StartTime
		AND ABID.BidDateTime  <= @EndTime
		AND AProductID.StatusDescription = 'Open'
		ORDER BY AuctionID,BidAmmount
	END

IF @@ROWCOUNT = 0
		PRINT ERROR_MESSAGE();
END;

GO


/*************************************  uspListBidsOffersHistory   ***********************************************/ 


/*************************************  uspUpdateProductAuctionStatus  ***********************************************/
--Since in our work the table Auction Product ID already has a collumn named "StatusDescription"
-- that updated the statusID and description if the maximum bid was reached, in this function we will only
-- update the auction in where the end data was reached.

CREATE OR ALTER PROCEDURE Auction.uspUpdateProductAuctionStatus

AS

DECLARE @CurrentDate datetime2 = GETDATE();


BEGIN
	BEGIN TRANSACTION

		UPDATE Auction.ProductID
		SET AuctionStatusId = 0, StatusDescription = 'Ended'
		WHERE  AuctionStatusID = 1
		and @CurrentDate > EndDate ;

	COMMIT TRANSACTION

BEGIN
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END
END





