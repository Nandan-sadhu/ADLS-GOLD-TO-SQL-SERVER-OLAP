-- =========================================================================
-- 1. CONTROL PLANE DDLS
-- =========================================================================
USE OLAPDB;
GO

-- Control Table A: Explicitly assigned to manage the History Loads
CREATE TABLE etl.control_table (
    TABLENAME VARCHAR(100) NOT NULL,
    STAGINGTABLENAME VARCHAR(100) NOT NULL,
    PROCEDURENAME VARCHAR(100) NOT NULL,
    LOADTYPE VARCHAR(10) CHECK (LOADTYPE IN ('SCD1', 'SCD2', 'FACT')),
    LOADORDER INT NOT NULL,
    ISACTIVE BIT DEFAULT 1,
    CONSTRAINT PK_BULK_CONTROL PRIMARY KEY (TABLENAME)
);
GO

-- =========================================================================
-- 2. METADATA SEEDING MATRIX
-- =========================================================================

-- Seed  Processing Layout (Points directly to LOAD routines)
INSERT INTO etl.control_table (TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE, LOADORDER, ISACTIVE) VALUES
('EMPLOYEE', 'staging.employee', 'etl.usp_load_employee', 'SCD1', 1, 1),
('DRIVER',   'staging.driver',   'etl.usp_load_driver',   'SCD1', 1, 1),
('TRUCK',    'staging.truck',    'etl.usp_load_truck',    'SCD1', 1, 1),
('CUSTOMER', 'staging.customer', 'etl.usp_load_customer', 'SCD2', 2, 1),
('PRODUCT',  'staging.product',  'etl.usp_load_product',  'SCD2', 2, 1),
('VENDOR',   'staging.vendor',   'etl.usp_load_vendor',   'SCD2', 2, 1),
('FACTTRIP', 'staging.facttrip', 'etl.usp_load_facttrip', 'FACT', 3, 1);
