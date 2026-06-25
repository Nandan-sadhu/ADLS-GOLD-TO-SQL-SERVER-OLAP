USE OLAPDB;
GO

CREATE OR ALTER PROCEDURE etl.usp_full_load_employee
    @CutoffWindow DATETIME  -- Passed dynamically from ADF (@pipeline().TriggerTime)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Empty the destination target table cleanly
        TRUNCATE TABLE gold_tables.EMPLOYEE;

        -- 2. Deduplicate staging and insert only the latest snapshot per Employee
        INSERT INTO gold_tables.EMPLOYEE (
            EmployeeID, 
            EmployeeName, 
            Department, 
            ModifiedDate
        )
        SELECT 
            EmployeeID, 
            EmployeeName, 
            Department, 
            ModifiedDate
        FROM (
            SELECT 
                EmployeeID, 
                EmployeeName, 
                Department, 
                ModifiedDate,
                ROW_NUMBER() OVER (
                    PARTITION BY EmployeeID 
                    ORDER BY ModifiedDate DESC, (SELECT NULL) -- Fast ordering fallback
                ) AS RowNumber
            FROM staging.employee
        ) AS DeduplicatedSource 
        WHERE RowNumber = 1;

        -- 3. Safely update the centralized tracking engine using the verified ADF window cut-off
        UPDATE gold_log.watermark_table 
        SET 
            LAST_WATERMARK_DATE = @CutoffWindow, 
            LAST_UPDATETIME = GETDATE() 
        WHERE TABLENAME = 'EMPLOYEE';

        -- Commit changes only if everything succeeds flawlessly
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        -- Roll back immediately if any error happens, preventing data loss
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        -- Propagate error back to ADF orchestrator
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Employee Full Load Aborted. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
