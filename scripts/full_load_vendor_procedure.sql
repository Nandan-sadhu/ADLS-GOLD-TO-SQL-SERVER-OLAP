USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_full_load_vendor
    @CutoffWindow DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        TRUNCATE TABLE gold_tables.VENDOR;

        INSERT INTO gold_tables.VENDOR (
            VendorID, VendorName, RowStartDateTime, RowEndDateTime, IsCurrent
        )
        SELECT 
            VendorID, VendorName, RowStartDateTime,
            CASE WHEN NextStart IS NULL THEN NULL ELSE DATEADD(SECOND, -1, NextStart) END,
            CASE WHEN NextStart IS NULL THEN 1 ELSE 0 END
        FROM (
            SELECT 
                VendorID, VendorName,
                ISNULL(ModifiedDate, '1900-01-01') AS RowStartDateTime,
                LEAD(ModifiedDate) OVER (PARTITION BY VendorID ORDER BY ModifiedDate ASC, (SELECT NULL)) AS NextStart
            FROM staging.vendor
        ) AS TimelineEngine;

        UPDATE gold_log.watermark_table 
        SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'VENDOR';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Vendor SCD2 Full Load Failed. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
