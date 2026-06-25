-- =========================================================================
-- SCD 1 TABLES
-- =========================================================================

DROP TABLE IF EXISTS gold_tables.EMPLOYEE;
DROP TABLE IF EXISTS gold_tables.DRIVER;
DROP TABLE IF EXISTS gold_tables.TRUCK;
GO

CREATE TABLE gold_tables.EMPLOYEE (
    EmployeeKey INT IDENTITY(1,1) NOT NULL, -- Surrogate Key
    EmployeeID INT NOT NULL,                -- Business Key
    EmployeeName VARCHAR(100) NULL,
    Department VARCHAR(50) NULL,
    ModifiedDate DATETIME NULL,
    CONSTRAINT PK_GOLD_EMPLOYEE PRIMARY KEY CLUSTERED (EmployeeKey)
);
CREATE UNIQUE NONCLUSTERED INDEX UIX_EMPLOYEE_ID ON gold_tables.EMPLOYEE(EmployeeID);

CREATE TABLE gold_tables.DRIVER (
    DriverKey INT IDENTITY(1,1) NOT NULL,
    DriverID INT NOT NULL,
    DriverName VARCHAR(100) NULL,
    LicenseNumber VARCHAR(50) NULL,
    ModifiedDate DATETIME NULL,
    CONSTRAINT PK_GOLD_DRIVER PRIMARY KEY CLUSTERED (DriverKey)
);
CREATE UNIQUE NONCLUSTERED INDEX UIX_DRIVER_ID ON gold_tables.DRIVER(DriverID);

CREATE TABLE gold_tables.TRUCK (
    TruckKey INT IDENTITY(1,1) NOT NULL,
    TruckID INT NOT NULL,
    TruckNumber VARCHAR(30) NULL,
    Model VARCHAR(50) NULL,
    ModifiedDate DATETIME NULL,
    CONSTRAINT PK_GOLD_TRUCK PRIMARY KEY CLUSTERED (TruckKey)
);
CREATE UNIQUE NONCLUSTERED INDEX UIX_TRUCK_ID ON gold_tables.TRUCK(TruckID);
GO

-- =========================================================================
-- SCD 2 TABLES
-- =========================================================================

  
DROP TABLE IF EXISTS gold_tables.CUSTOMER;
DROP TABLE IF EXISTS gold_tables.PRODUCT;
DROP TABLE IF EXISTS gold_tables.VENDOR;
GO

CREATE TABLE gold_tables.CUSTOMER (
    CustomerKey INT IDENTITY(1,1) NOT NULL,
    CustomerID INT NOT NULL,
    CustomerName VARCHAR(100) NULL,
    Region VARCHAR(50) NULL,
    RowStartDateTime DATETIME NOT NULL,
    RowEndDateTime DATETIME NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_GOLD_CUSTOMER PRIMARY KEY CLUSTERED (CustomerKey)
);
CREATE NONCLUSTERED INDEX IX_CUSTOMER_SCD2 ON gold_tables.CUSTOMER(CustomerID, IsCurrent);

CREATE TABLE gold_tables.PRODUCT (
    ProductKey INT IDENTITY(1,1) NOT NULL,
    ProductID INT NOT NULL,
    ProductName VARCHAR(100) NULL,
    Category VARCHAR(50) NULL,
    UnitPrice DECIMAL(18,2) NULL,
    RowStartDateTime DATETIME NOT NULL,
    RowEndDateTime DATETIME NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_GOLD_PRODUCT PRIMARY KEY CLUSTERED (ProductKey)
);
CREATE NONCLUSTERED INDEX IX_PRODUCT_SCD2 ON gold_tables.PRODUCT(ProductID, IsCurrent);

CREATE TABLE gold_tables.VENDOR (
    VendorKey INT IDENTITY(1,1) NOT NULL,
    VendorID INT NOT NULL,
    VendorName VARCHAR(100) NULL,
    RowStartDateTime DATETIME NOT NULL,
    RowEndDateTime DATETIME NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_GOLD_VENDOR PRIMARY KEY CLUSTERED (VendorKey)
);
CREATE NONCLUSTERED INDEX IX_VENDOR_SCD2 ON gold_tables.VENDOR(VendorID, IsCurrent);
GO

-- =========================================================================
-- FACT TABLE
-- =========================================================================
  
DROP TABLE IF EXISTS gold_tables.FACTTRIP;
GO

CREATE TABLE gold_tables.FACTTRIP (
    TripFactKey BIGINT IDENTITY(1,1) NOT NULL,
    TripID INT NOT NULL,
    EmployeeKey INT NOT NULL,  -- Reference to gold_tables.EMPLOYEE
    DriverKey INT NOT NULL,    -- Reference to gold_tables.DRIVER
    TruckKey INT NOT NULL,     -- Reference to gold_tables.TRUCK
    CustomerKey INT NOT NULL,  -- Reference to gold_tables.CUSTOMER
    ProductKey INT NOT NULL,   -- Reference to gold_tables.PRODUCT
    VendorKey INT NOT NULL,    -- Reference to gold_tables.VENDOR
    TripDistance DECIMAL(10,2) NULL,
    Revenue DECIMAL(18,2) NULL,
    TripDate DATETIME NULL,
    LoadDateTime DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_FACT_TRIP PRIMARY KEY CLUSTERED (TripFactKey),
    
    -- Enforcing Referential Integrity constraints back to your Dimensions
    CONSTRAINT FK_FACTTRIP_EMPLOYEE FOREIGN KEY (EmployeeKey) REFERENCES gold_tables.EMPLOYEE(EmployeeKey),
    CONSTRAINT FK_FACTTRIP_DRIVER   FOREIGN KEY (DriverKey)   REFERENCES gold_tables.DRIVER(DriverKey),
    CONSTRAINT FK_FACTTRIP_TRUCK    FOREIGN KEY (TruckKey)    REFERENCES gold_tables.TRUCK(TruckKey),
    CONSTRAINT FK_FACTTRIP_CUSTOMER FOREIGN KEY (CustomerKey) REFERENCES gold_tables.CUSTOMER(CustomerKey),
    CONSTRAINT FK_FACTTRIP_PRODUCT  FOREIGN KEY (ProductKey)  REFERENCES gold_tables.PRODUCT(ProductKey),
    CONSTRAINT FK_FACTTRIP_VENDOR   FOREIGN KEY (VendorKey)   REFERENCES gold_tables.VENDOR(VendorKey)
);

-- Indexing foreign keys for rapid analytical aggregations and joins
CREATE NONCLUSTERED INDEX IX_FACTTRIP_FK_LOOKUPS ON gold_tables.FACTTRIP (EmployeeKey, DriverKey, TruckKey, CustomerKey, ProductKey, VendorKey);
GO
