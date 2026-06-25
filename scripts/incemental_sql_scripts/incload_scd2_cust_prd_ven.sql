USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_inc_load_customer
    @CutoffWindow DATETIME -- Bounded securely by Azure Data Factory
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- =========================================================================
        -- STEP 1: ISOLATE REAL CHANGES & PREVENT BLANK TIMELINE BLOAT
        -- =========================================================================
        -- We compare staging to the active production row. If a record arrives 
        -- with no changes to the actual attributes (Name/Region), we filter it out.
        SELECT 
            stg.CustomerID,
            stg.CustomerName,
            stg.Region,
            stg.ModifiedDate
        INTO #FilteredDelta
        FROM staging.customer stg
        LEFT JOIN gold_tables.CUSTOMER tgt 
            ON stg.CustomerID = tgt.CustomerID 
           AND tgt.IsCurrent = 1
        WHERE tgt.CustomerKey IS NULL -- Brand new record
           OR ISNULL(tgt.CustomerName, '') <> ISNULL(stg.CustomerName, '') -- Actual Name change
           OR ISNULL(tgt.Region, '') <> ISNULL(stg.Region, '');            -- Actual Region change

        -- If no rows passed the mutation filter, skip processing entirely to protect resources
        IF EXISTS (SELECT 1 FROM #FilteredDelta)
        BEGIN

            -- =========================================================================
            -- STEP 2: ACTION 1 - CLOSE OUT REVISED WAREHOUSE RECORDS
            -- =========================================================================
            -- Expirate old current rows using the earliest incoming timestamp minus 1 second
            UPDATE tgt
            SET 
                tgt.RowEndDateTime = DATEADD(SECOND, -1, src.FirstNewDate),
                tgt.IsCurrent = 0
            FROM gold_tables.CUSTOMER tgt WITH (UPDLOCK)
            INNER JOIN (
                SELECT CustomerID, MIN(ModifiedDate) AS FirstNewDate
                FROM #FilteredDelta
                GROUP BY CustomerID
            ) AS src ON tgt.CustomerID = src.CustomerID
            WHERE tgt.IsCurrent = 1;

            -- =========================================================================
            -- STEP 3: ACTION 2 - INTERPOLATE MULTI-ROW TRANSITIONS INTO TARGET
            -- =========================================================================
            -- Dynamically construct timelines using LEAD across the filtered dataset
            INSERT INTO gold_tables.CUSTOMER (
                CustomerID, 
                CustomerName, 
                Region, 
                RowStartDateTime, 
                RowEndDateTime, 
                IsCurrent
            )
            SELECT 
                CustomerID,
                CustomerName,
                Region,
                RowStartDateTime,
                -- Deduct 1 second from future records within the same batch to maintain chronology
                CASE 
                    WHEN NextStart IS NULL THEN NULL 
                    ELSE DATEADD(SECOND, -1, NextStart) 
                END AS RowEndDateTime,
                CASE 
                    WHEN NextStart IS NULL THEN 1 
                    ELSE 0 
                END AS IsCurrent
            FROM (
                SELECT 
                    CustomerID,
                    CustomerName,
                    Region,
                    ISNULL(ModifiedDate, '1900-01-01') AS RowStartDateTime,
                    LEAD(ModifiedDate) OVER (
                        PARTITION BY CustomerID 
                        ORDER BY ModifiedDate ASC
                    ) AS NextStart
                FROM #FilteredDelta
            ) AS TimelineEngine;

        END;

        -- =========================================================================
        -- STEP 4: UPDATE CENTRAL LOG ENGINE
        -- =========================================================================
        UPDATE gold_log.watermark_table 
        SET 
            LAST_WATERMARK_DATE = @CutoffWindow, 
            LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'CUSTOMER';

        -- Cleanup memory footprint safely
        DROP TABLE IF EXISTS #FilteredDelta;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #FilteredDelta;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Customer Multi-Row SCD2 Incremental Failed. Reason: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
-- ---------------
CREATE OR ALTER PROCEDURE etl.usp_inc_load_product
    @CutoffWindow DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT stg.ProductID, stg.ProductName, stg.Category, stg.UnitPrice, stg.ModifiedDate
        INTO #FilteredProduct
        FROM staging.product stg
        LEFT JOIN gold_tables.PRODUCT tgt ON stg.ProductID = tgt.ProductID AND tgt.IsCurrent = 1
        WHERE tgt.ProductKey IS NULL
           OR ISNULL(tgt.ProductName, '') <> ISNULL(stg.ProductName, '')
           OR ISNULL(tgt.Category, '') <> ISNULL(stg.Category, '')
           OR ISNULL(tgt.UnitPrice, 0) <> ISNULL(stg.UnitPrice, 0);

        IF EXISTS (SELECT 1 FROM #FilteredProduct)
        BEGIN
            UPDATE tgt
            SET tgt.RowEndDateTime = DATEADD(SECOND, -1, src.FirstNewDate), tgt.IsCurrent = 0
            FROM gold_tables.PRODUCT tgt WITH (UPDLOCK)
            INNER JOIN (SELECT ProductID, MIN(ModifiedDate) AS FirstNewDate FROM #FilteredProduct GROUP BY ProductID) AS src 
                ON tgt.ProductID = src.ProductID WHERE tgt.IsCurrent = 1;

            INSERT INTO gold_tables.PRODUCT (ProductID, ProductName, Category, UnitPrice, RowStartDateTime, RowEndDateTime, IsCurrent)
            SELECT ProductID, ProductName, Category, UnitPrice, RowStartDateTime,
                   CASE WHEN NextStart IS NULL THEN NULL ELSE DATEADD(SECOND, -1, NextStart) END,
                   CASE WHEN NextStart IS NULL THEN 1 ELSE 0 END
            FROM (
                SELECT ProductID, ProductName, Category, UnitPrice, ISNULL(ModifiedDate, '1900-01-01') AS RowStartDateTime,
                       LEAD(ModifiedDate) OVER (PARTITION BY ProductID ORDER BY ModifiedDate ASC) AS NextStart
                FROM #FilteredProduct
            ) AS T;
        END;

        UPDATE gold_log.watermark_table SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() WHERE TABLENAME = 'PRODUCT';
        DROP TABLE IF EXISTS #FilteredProduct;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; DROP TABLE IF EXISTS #FilteredProduct;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE(); RAISERROR('Product Incremental Failed. Reason: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
-- ----------

USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_inc_load_vendor
    @CutoffWindow DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT stg.VendorID, stg.VendorName, stg.ModifiedDate
        INTO #FilteredVendor
        FROM staging.vendor stg
        LEFT JOIN gold_tables.VENDOR tgt ON stg.VendorID = tgt.VendorID AND tgt.IsCurrent = 1
        WHERE tgt.VendorKey IS NULL
           OR ISNULL(tgt.VendorName, '') <> ISNULL(stg.VendorName, '');

        IF EXISTS (SELECT 1 FROM #FilteredVendor)
        BEGIN
            UPDATE tgt
            SET tgt.RowEndDateTime = DATEADD(SECOND, -1, src.FirstNewDate), tgt.IsCurrent = 0
            FROM gold_tables.VENDOR tgt WITH (UPDLOCK)
            INNER JOIN (SELECT VendorID, MIN(ModifiedDate) AS FirstNewDate FROM #FilteredVendor GROUP BY VendorID) AS src 
                ON tgt.VendorID = src.VendorID WHERE tgt.IsCurrent = 1;

            INSERT INTO gold_tables.VENDOR (VendorID, VendorName, RowStartDateTime, RowEndDateTime, IsCurrent)
            SELECT VendorID, VendorName, RowStartDateTime,
                   CASE WHEN NextStart IS NULL THEN NULL ELSE DATEADD(SECOND, -1, NextStart) END,
                   CASE WHEN NextStart IS NULL THEN 1 ELSE 0 END
            FROM (
                SELECT VendorID, VendorName, ISNULL(ModifiedDate, '1900-01-01') AS RowStartDateTime,
                       LEAD(ModifiedDate) OVER (PARTITION BY VendorID ORDER BY ModifiedDate ASC) AS NextStart
                FROM #FilteredVendor
            ) AS T;
        END;

        UPDATE gold_log.watermark_table SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() WHERE TABLENAME = 'VENDOR';
        DROP TABLE IF EXISTS #FilteredVendor;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; DROP TABLE IF EXISTS #FilteredVendor;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE(); RAISERROR('Vendor Incremental Failed. Reason: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
-- -------------------
