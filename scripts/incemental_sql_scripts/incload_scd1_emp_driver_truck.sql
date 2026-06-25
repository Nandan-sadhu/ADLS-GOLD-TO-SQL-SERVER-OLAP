USE OLAPDB;
GO

-- 1. Employee Incremental
CREATE OR ALTER PROCEDURE etl.usp_incremental_load_employee
    @CutoffWindow DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE gold_tables.EMPLOYEE AS TARGET
        USING (
            SELECT EmployeeID, EmployeeName, Department, ModifiedDate
            FROM (
                SELECT EmployeeID, EmployeeName, Department, ModifiedDate,
                       ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY ModifiedDate DESC) AS RowNum
                FROM staging.employee
            ) AS FreshDelta WHERE RowNum = 1
        ) AS SOURCE ON TARGET.EmployeeID = SOURCE.EmployeeID
        WHEN MATCHED AND SOURCE.ModifiedDate > TARGET.ModifiedDate THEN
            UPDATE SET TARGET.EmployeeName = SOURCE.EmployeeName, TARGET.Department = SOURCE.Department, TARGET.ModifiedDate = SOURCE.ModifiedDate
        WHEN NOT MATCHED THEN
            INSERT (EmployeeID, EmployeeName, Department, ModifiedDate) VALUES (SOURCE.EmployeeID, SOURCE.EmployeeName, SOURCE.Department, SOURCE.ModifiedDate);

        UPDATE gold_log.watermark_table SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() WHERE TABLENAME = 'EMPLOYEE'; 
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Employee Incremental Load Failed. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO

-- 2. Driver Incremental
CREATE OR ALTER PROCEDURE etl.usp_incremental_load_driver
    @CutoffWindow DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE gold_tables.DRIVER AS TARGET
        USING (
            SELECT DriverID, DriverName, LicenseNumber, ModifiedDate
            FROM (
                SELECT DriverID, DriverName, LicenseNumber, ModifiedDate,
                       ROW_NUMBER() OVER (PARTITION BY DriverID ORDER BY ModifiedDate DESC) AS RowNum
                FROM staging.driver
            ) AS FreshDelta WHERE RowNum = 1
        ) AS SOURCE ON TARGET.DriverID = SOURCE.DriverID
        WHEN MATCHED AND SOURCE.ModifiedDate > TARGET.ModifiedDate THEN
            UPDATE SET TARGET.DriverName = SOURCE.DriverName, TARGET.LicenseNumber = SOURCE.LicenseNumber, TARGET.ModifiedDate = SOURCE.ModifiedDate
        WHEN NOT MATCHED THEN
            INSERT (DriverID, DriverName, LicenseNumber, ModifiedDate) VALUES (SOURCE.DriverID, SOURCE.DriverName, SOURCE.LicenseNumber, SOURCE.ModifiedDate);

        UPDATE gold_log.watermark_table SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() WHERE TABLENAME = 'DRIVER'; 
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Driver Incremental Load Failed. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO

-- 3. Truck Incremental
CREATE OR ALTER PROCEDURE etl.usp_incremental_load_truck
    @CutoffWindow DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE gold_tables.TRUCK AS TARGET
        USING (
            SELECT TruckID, TruckNumber, Model, ModifiedDate
            FROM (
                SELECT TruckID, TruckNumber, Model, ModifiedDate,
                       ROW_NUMBER() OVER (PARTITION BY TruckID ORDER BY ModifiedDate DESC) AS RowNum
                FROM staging.truck
            ) AS FreshDelta WHERE RowNum = 1
        ) AS SOURCE ON TARGET.TruckID = SOURCE.TruckID
        WHEN MATCHED AND SOURCE.ModifiedDate > TARGET.ModifiedDate THEN
            UPDATE SET TARGET.TruckNumber = SOURCE.TruckNumber, TARGET.Model = SOURCE.Model, TARGET.ModifiedDate = SOURCE.ModifiedDate
        WHEN NOT MATCHED THEN
            INSERT (TruckID, TruckNumber, Model, ModifiedDate) VALUES (SOURCE.TruckID, SOURCE.TruckNumber, SOURCE.Model, SOURCE.ModifiedDate);

        UPDATE gold_log.watermark_table SET LAST_WATERMARK_DATE = @CutoffWindow, LAST_UPDATETIME = GETDATE() WHERE TABLENAME = 'TRUCK'; 
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Truck Incremental Load Failed. Error: %s', 16, 1, @ErrorMsg);
    END CATCH;
END;
GO
