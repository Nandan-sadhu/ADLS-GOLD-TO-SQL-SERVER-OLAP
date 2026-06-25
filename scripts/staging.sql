USE OLAPDB;
GO

-- Cleanup existing staging tables to ensure clean deployment
DROP TABLE IF EXISTS staging.employee;
DROP TABLE IF EXISTS staging.driver;
DROP TABLE IF EXISTS staging.truck;
DROP TABLE IF EXISTS staging.customer;
DROP TABLE IF EXISTS staging.product;
DROP TABLE IF EXISTS staging.vendor;
DROP TABLE IF EXISTS staging.facttrip;
GO

-- SCD1 Staging Tables
CREATE TABLE staging.employee (
    EmployeeID INT NULL,
    EmployeeName VARCHAR(100) NULL,
    Department VARCHAR(50) NULL,
    ModifiedDate DATETIME NULL
);

CREATE TABLE staging.driver (
    DriverID INT NULL,
    DriverName VARCHAR(100) NULL,
    LicenseNumber VARCHAR(50) NULL,
    ModifiedDate DATETIME NULL
);

CREATE TABLE staging.truck (
    TruckID INT NULL,
    TruckNumber VARCHAR(30) NULL,
    Model VARCHAR(50) NULL,
    ModifiedDate DATETIME NULL
);

-- SCD2 Staging Tables
CREATE TABLE staging.customer (
    CustomerID INT NULL,
    CustomerName VARCHAR(100) NULL,
    Region VARCHAR(50) NULL,
    ModifiedDate DATETIME NULL
);

CREATE TABLE staging.product (
    ProductID INT NULL,
    ProductName VARCHAR(100) NULL,
    Category VARCHAR(50) NULL,
    UnitPrice DECIMAL(18,2) NULL,
    ModifiedDate DATETIME NULL
);

CREATE TABLE staging.vendor (
    VendorID INT NULL,
    VendorName VARCHAR(100) NULL,
    ModifiedDate DATETIME NULL
);

-- Fact Staging Table
CREATE TABLE staging.facttrip (
    TripID INT NULL,
    EmployeeID INT NULL,
    DriverID INT NULL,
    TruckID INT NULL,
    CustomerID INT NULL,
    ProductID INT NULL,
    VendorID INT NULL,
    TripDistance DECIMAL(10,2) NULL,
    Revenue DECIMAL(18,2) NULL,
    TripDate DATETIME NULL
);
GO
