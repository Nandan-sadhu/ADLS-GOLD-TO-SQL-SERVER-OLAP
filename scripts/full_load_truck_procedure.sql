USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_full_load_truck
    @CutoffWindow DATETIME  -- Passed dynamically from ADF (@pipeline().TriggerTime)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Clear the target dimension table cleanly
        TRUNCATE TABLE gold_tables.TRUCK;

        -- 2. Deduplicate staging data and insert the latest snapshot per Truck
        INSERT INTO gold_tables.TRUCK (
            TruckID, 
            TruckNumber, 
            Model, 
            ModifiedDate
        )
        SELECT 
            TruckID, 
            TruckNumber, 
            Model, 
            ModifiedDate
        FROM (
            SELECT 
                TruckID, 
                TruckNumber, 
                Model, 
                ModifiedDate,
                ROW_NUMBER() OVER (
                    PARTITION BY TruckID 
                    ORDER BY ModifiedDate DESC, (SELECT NULL)
                ) AS RowNumber
            FROM staging.truck
        ) AS DeduplicatedSource 
        WHERE RowNumber = 1;

        -- 3. Update the tracking table to sync the ADF window boundary
        UPDATE gold_log.watermark_table 
        SET 
            LAST_WATERMARK_DATE = @CutoffWindow, 
            LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'TRUCK';

        -- Commit changes only if everything executes successfully
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        -- Rollback immediately on error to prevent partial/failed state commits
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        -- Propagate error tracking to the ADF orchestrator
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Truck Full Load Aborted. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
