USE OLAPDB;
GO

-- Temporarily bypass IDENTITY_INSERT blocks to enforce the -1 key structures
SET IDENTITY_INSERT gold_tables.EMPLOYEE ON;
INSERT INTO gold_tables.EMPLOYEE (EmployeeKey, EmployeeID, EmployeeName, Department) VALUES (-1, -1, 'Missing Employee', 'Unknown');
SET IDENTITY_INSERT gold_tables.EMPLOYEE OFF;

SET IDENTITY_INSERT gold_tables.DRIVER ON;
INSERT INTO gold_tables.DRIVER (DriverKey, DriverID, DriverName, LicenseNumber) VALUES (-1, -1, 'Missing Driver', 'Unknown');
SET IDENTITY_INSERT gold_tables.DRIVER OFF;

SET IDENTITY_INSERT gold_tables.TRUCK ON;
INSERT INTO gold_tables.TRUCK (TruckKey, TruckID, TruckNumber, Model) VALUES (-1, -1, 'Missing Truck', 'Unknown');
SET IDENTITY_INSERT gold_tables.TRUCK OFF;

SET IDENTITY_INSERT gold_tables.CUSTOMER ON;
INSERT INTO gold_tables.CUSTOMER (CustomerKey, CustomerID, CustomerName, Region, RowStartDateTime, RowEndDateTime, IsCurrent) 
VALUES (-1, -1, 'Missing Customer', 'Unknown', '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT gold_tables.CUSTOMER OFF;

SET IDENTITY_INSERT gold_tables.PRODUCT ON;
INSERT INTO gold_tables.PRODUCT (ProductKey, ProductID, ProductName, Category, UnitPrice, RowStartDateTime, RowEndDateTime, IsCurrent) 
VALUES (-1, -1, 'Missing Product', 'Unknown', 0.00, '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT gold_tables.PRODUCT OFF;

SET IDENTITY_INSERT gold_tables.VENDOR ON;
INSERT INTO gold_tables.VENDOR (VendorKey, VendorID, VendorName, RowStartDateTime, RowEndDateTime, IsCurrent) 
VALUES (-1, -1, 'Missing Vendor', 'Unknown', '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT gold_tables.VENDOR OFF;
GO
