-- =========================================================================
-- 1. CONTROL PLANE DDLS
-- =========================================================================
USE OLAPDB;
GO

-- Control Table A: Explicitly assigned to manage the One-Time Bulk/Full History Load
CREATE TABLE etl.bulk_control_table (
    TABLENAME VARCHAR(100) NOT NULL,
    STAGINGTABLENAME VARCHAR(100) NOT NULL,
    PROCEDURENAME VARCHAR(100) NOT NULL,
    LOADTYPE VARCHAR(10) CHECK (LOADTYPE IN ('SCD1', 'SCD2', 'FACT')),
    LOADORDER INT NOT NULL,
    ISACTIVE BIT DEFAULT 1,
    CONSTRAINT PK_BULK_CONTROL PRIMARY KEY (TABLENAME)
);

-- Control Table B: Explicitly assigned to manage the Continuous Delta/Daily Incremental Runs
CREATE TABLE etl.incremental_control_table (
    TABLENAME VARCHAR(100) NOT NULL,
    STAGINGTABLENAME VARCHAR(100) NOT NULL,
    PROCEDURENAME VARCHAR(100) NOT NULL,
    LOADTYPE VARCHAR(10) CHECK (LOADTYPE IN ('SCD1', 'SCD2', 'FACT')),
    LOADORDER INT NOT NULL,
    ISACTIVE BIT DEFAULT 1,
    CONSTRAINT PK_INCREMENTAL_CONTROL PRIMARY KEY (TABLENAME)
);
GO

-- =========================================================================
-- 2. METADATA SEEDING MATRIX
-- =========================================================================

-- Seed Bulk Processing Layout (Points directly to FULL_LOAD routines)
INSERT INTO etl.bulk_control_table (TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE, LOADORDER, ISACTIVE) VALUES
('EMPLOYEE', 'staging.employee', 'etl.usp_full_load_employee', 'SCD1', 1, 1),
('DRIVER',   'staging.driver',   'etl.usp_full_load_driver',   'SCD1', 1, 1),
('TRUCK',    'staging.truck',    'etl.usp_full_load_truck',    'SCD1', 1, 1),
('CUSTOMER', 'staging.customer', 'etl.usp_full_load_customer', 'SCD2', 2, 1),
('PRODUCT',  'staging.product',  'etl.usp_full_load_product',  'SCD2', 2, 1),
('VENDOR',   'staging.vendor',   'etl.usp_full_load_vendor',   'SCD2', 2, 1),
('FACTTRIP', 'staging.facttrip', 'etl.usp_full_load_facttrip', 'FACT', 3, 1);

-- Seed Incremental Processing Layout (Points directly to INCREMENTAL_LOAD / MERGE routines)
INSERT INTO etl.incremental_control_table (TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE, LOADORDER, ISACTIVE) VALUES
('EMPLOYEE', 'staging.employee', 'etl.usp_incremental_load_employee', 'SCD1', 1, 1),
('DRIVER',   'staging.driver',   'etl.usp_incremental_load_driver',   'SCD1', 1, 1),
('TRUCK',    'staging.truck',    'etl.usp_incremental_load_truck',    'SCD1', 1, 1),
('CUSTOMER', 'staging.customer', 'etl.usp_incremental_load_customer', 'SCD2', 2, 1),
('PRODUCT',  'staging.product',  'etl.usp_incremental_load_product',  'SCD2', 2, 1),
('VENDOR',   'staging.vendor',   'etl.usp_incremental_load_vendor',   'SCD2', 2, 1),
('FACTTRIP', 'staging.facttrip', 'etl.usp_incremental_load_facttrip', 'FACT', 3, 1);
GO
