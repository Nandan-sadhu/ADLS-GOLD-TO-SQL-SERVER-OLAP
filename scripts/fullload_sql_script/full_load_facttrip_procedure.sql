USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_full_load_facttrip
    @CutoffWindow DATETIME -- Driven deterministically by ADF
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Hard purge the target fact table cleanly
        -- Note: If foreign keys are active, TRUNCATE works as long as it's not the parent table.
        TRUNCATE TABLE gold_tables.FACTTRIP;

        -- 2. Bulk insert data with point-in-time surrogate key transformations
        INSERT INTO gold_tables.FACTTRIP (
            TripID,
            EmployeeKey,
            DriverKey,
            TruckKey,
            CustomerKey,
            ProductKey,
            VendorKey,
            TripDistance,
            Revenue,
            TripDate,
            LoadDateTime
        )
        SELECT 
            stg.TripID,
            -- SCD1 Dimension Transformations (Fallback to -1 if orphan record occurs)
            ISNULL(emp.EmployeeKey, -1) AS EmployeeKey,
            ISNULL(drv.DriverKey, -1)   AS DriverKey,
            ISNULL(tck.TruckKey, -1)    AS TruckKey,
            
            -- SCD2 Historical Timeline Dimension Transformations (Safeguarded against NULL boundaries)
            ISNULL(cust.CustomerKey, -1) AS CustomerKey,
            ISNULL(prod.ProductKey, -1)   AS ProductKey,
            ISNULL(vnd.VendorKey, -1)     AS VendorKey,
            
            stg.TripDistance,
            stg.Revenue,
            stg.TripDate,
            GETDATE() AS LoadDateTime
        FROM staging.facttrip stg
        
        -- JONING SCD1 LAYER (Matches on absolute business key)
        LEFT JOIN gold_tables.EMPLOYEE emp 
            ON stg.EmployeeID = emp.EmployeeID
            
        LEFT JOIN gold_tables.DRIVER drv   
            ON stg.DriverID = drv.DriverID
            
        LEFT JOIN gold_tables.TRUCK tck    
            ON stg.TruckID = tck.TruckID
            
        -- JOINING SCD2 LAYER (Point-in-Time version tracking evaluation)
        LEFT JOIN gold_tables.CUSTOMER cust 
            ON stg.CustomerID = cust.CustomerID
            AND stg.TripDate >= cust.RowStartDateTime 
            AND stg.TripDate <= ISNULL(cust.RowEndDateTime, '9999-12-31 23:59:59')
            
        LEFT JOIN gold_tables.PRODUCT prod  
            ON stg.ProductID = prod.ProductID
            AND stg.TripDate >= prod.RowStartDateTime 
            AND stg.TripDate <= ISNULL(prod.RowEndDateTime, '9999-12-31 23:59:59')
            
        LEFT JOIN gold_tables.VENDOR vnd    
            ON stg.VendorID = vnd.VendorID
            AND stg.TripDate >= vnd.RowStartDateTime 
            AND stg.TripDate <= ISNULL(vnd.RowEndDateTime, '9999-12-31 23:59:59');

        -- 3. Update the centralized watermark log 
        UPDATE gold_log.watermark_table 
        SET 
            LAST_WATERMARK_DATE = @CutoffWindow, 
            LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'FACTTRIP';

        -- Commit changes cleanly
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        -- Roll back immediately if failure strikes
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        -- Return specific error text back to your ADF grandchild process
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('FactTrip Full Load Process Failed. Reason: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
