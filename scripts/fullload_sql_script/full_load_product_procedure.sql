USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_full_load_product
    @CutoffWindow DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        TRUNCATE TABLE gold_tables.PRODUCT;

        INSERT INTO gold_tables.PRODUCT (
            ProductID, ProductName, Category, UnitPrice, RowStartDateTime, RowEndDateTime, IsCurrent
        )
        SELECT 
            ProductID, ProductName, Category, UnitPrice, RowStartDateTime,
            CASE WHEN NextStart IS NULL THEN NULL ELSE DATEADD(SECOND, -1, NextStart) END,
            CASE WHEN NextStart IS NULL THEN 1 ELSE 0 END
        FROM (
            SELECT 
                ProductID, ProductName, Category, UnitPrice,
                ISNULL(ModifiedDate, '1900-01-01') AS RowStartDateTime,
                LEAD(ModifiedDate) OVER (PARTITION BY ProductID ORDER BY ModifiedDate ASC, (SELECT NULL)) AS NextStart
            FROM staging.product
        ) AS TimelineEngine;

        UPDATE gold_log.watermark_table 
        SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'PRODUCT';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Product SCD2 Full Load Failed. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
