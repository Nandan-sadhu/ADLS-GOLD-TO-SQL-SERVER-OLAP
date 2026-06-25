USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_full_load_customer
    @CutoffWindow DATETIME -- Managed deterministically by ADF
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Hard purge historical state for clean rebuild
        TRUNCATE TABLE gold_tables.CUSTOMER;

        -- Construct perfect historical SCD2 timelines using an optimized subquery
        INSERT INTO gold_tables.CUSTOMER (
            CustomerID, CustomerName, Region, RowStartDateTime, RowEndDateTime, IsCurrent
        )
        SELECT 
            CustomerID,
            CustomerName,
            Region,
            RowStartDateTime,
            -- If a subsequent record exists, deduct 1 second to prevent overlapping timelines
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
                    ORDER BY ModifiedDate ASC, (SELECT NULL)
                ) AS NextStart
            FROM staging.customer
        ) AS TimelineEngine;

        -- Sync metadata log to pipeline cut-off safely
        UPDATE gold_log.watermark_table 
        SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'CUSTOMER';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Customer SCD2 Full Load Failed. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
