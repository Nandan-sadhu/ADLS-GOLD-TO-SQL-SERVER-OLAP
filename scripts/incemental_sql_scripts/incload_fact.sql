USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_inc_load_facttrip
    @CutoffWindow DATETIME -- Managed dynamically and deterministically by ADF
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        -- =========================================================================
        -- STEP 1: ENFORCE AUTOMATIC IDEMPOTENCY (PREVENT DUPLICATE RE-RUN RUNS)
        -- =========================================================================
        -- If an ADF pipeline fails mid-execution and is restarted, this clearing 
        -- block deletes existing target rows to guarantee clean data.
        DELETE tgt
        FROM gold_tables.FACTTRIP tgt
        INNER JOIN staging.facttrip stg ON tgt.TripID = stg.TripID;

        -- =========================================================================
        -- STEP 2: INCREMENTAL INGESTION WITH SURROGATE KEY TRANSLATIONS
        -- =========================================================================
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
            -- SCD1 Key Lookups (Fall back to -1 if an orphan record is found)
            ISNULL(emp.EmployeeKey, -1) AS EmployeeKey,
            ISNULL(drv.DriverKey, -1)   AS DriverKey,
            ISNULL(tck.TruckKey, -1)    AS TruckKey,
            
            -- SCD2 Point-in-Time Lookups (Safeguarded against active NULL timelines)
            ISNULL(cust.CustomerKey, -1) AS CustomerKey,
            ISNULL(prod.ProductKey, -1)   AS ProductKey,
            ISNULL(vnd.VendorKey, -1)     AS VendorKey,
            
            stg.TripDistance,
            stg.Revenue,
            stg.TripDate,
            GETDATE() AS LoadDateTime
        FROM staging.facttrip stg
        
        -- Join against Type 1 Entities on exact business keys
        LEFT JOIN gold_tables.EMPLOYEE emp ON stg.EmployeeID = emp.EmployeeID
        LEFT JOIN gold_tables.DRIVER   drv ON stg.DriverID   = drv.DriverID
        LEFT JOIN gold_tables.TRUCK    tck ON stg.TruckID    = tck.TruckID
        
        -- Join against Type 2 Entities using non-overlapping date boundaries
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

        -- =========================================================================
        -- STEP 3: ADVANCE THE CONTROL PLANE WATERMARK LOG
        -- =========================================================================
        UPDATE gold_log.watermark_table 
        SET 
            LAST_WATERMARK_DATE = @CutoffWindow, 
            LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'FACTTRIP';

        -- Commit changes only if everything succeeds flawlessly
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        -- Immediate rollback on failure to protect transactional integrity
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        -- Propagate error tracking back up to the ADF orchestrator
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('FactTrip Incremental Execution Aborted. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
