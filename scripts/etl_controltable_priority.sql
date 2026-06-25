USE OLAPDB;
GO

-- Safe drop if re-running
DROP TABLE IF EXISTS etl.inc_load_control_table;
DROP TABLE IF EXISTS etl.full_load_control_table;
DROP TABLE IF EXISTS gold_log.watermark_table;
GO

-- 1. Full Load Control
CREATE TABLE etl.full_load_control_table (
    TARGET_SCHEMA VARCHAR(50) NOT NULL DEFAULT 'gold_tables',
    TABLENAME VARCHAR(100) NOT NULL,
    STAGING_SCHEMA VARCHAR(50) NOT NULL DEFAULT 'staging',
    STAGINGTABLENAME VARCHAR(100) NOT NULL,
    PROCEDURENAME VARCHAR(100) NOT NULL,
    LOADTYPE VARCHAR(10) CHECK (LOADTYPE IN ('SCD1', 'SCD2', 'FACT')),
    LOADORDER INT NOT NULL,
    ISACTIVE BIT DEFAULT 1,
    CONSTRAINT PK_FULL_CONTROL PRIMARY KEY (TARGET_SCHEMA, TABLENAME)
);

-- 2. Incremental/Bulk Load Control
CREATE TABLE etl.inc_load_control_table (
    TARGET_SCHEMA VARCHAR(50) NOT NULL DEFAULT 'gold_tables',
    TABLENAME VARCHAR(100) NOT NULL,
    STAGING_SCHEMA VARCHAR(50) NOT NULL DEFAULT 'staging',
    STAGINGTABLENAME VARCHAR(100) NOT NULL,
    PROCEDURENAME VARCHAR(100) NOT NULL,
    LOADTYPE VARCHAR(10) CHECK (LOADTYPE IN ('SCD1', 'SCD2', 'FACT')),
    LOADORDER INT NOT NULL,
    ISACTIVE BIT DEFAULT 1,
    CONSTRAINT PK_BULK_CONTROL PRIMARY KEY (TARGET_SCHEMA, TABLENAME)
);

-- 3. Watermark Engine
CREATE TABLE gold_log.watermark_table (
    TABLENAME VARCHAR(100) NOT NULL,
    LAST_WATERMARK_DATE DATETIME NOT NULL DEFAULT '1900-01-01',
    LAST_UPDATETIME DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_WATERMARK PRIMARY KEY (TABLENAME)
);
GO

-- [Inserts for etl.full_load_control_table and etl.bulk_load_control_table execute perfectly here...]

-- Fixed Seed Statement:
INSERT INTO gold_log.watermark_table (TABLENAME, LAST_WATERMARK_DATE)
SELECT TABLENAME, '1900-01-01' FROM etl.full_load_control_table;
GO

USE OLAPDB;
GO

-- Clear existing data to prevent primary key violation errors if re-running
TRUNCATE TABLE etl.full_load_control_table;
TRUNCATE TABLE etl.bulk_load_control_table;
GO

-- =========================================================================
-- A. SEEDING THE FULL LOAD CONTROL TABLE
-- =========================================================================
INSERT INTO etl.full_load_control_table 
    (TARGET_SCHEMA, TABLENAME, STAGING_SCHEMA, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE, LOADORDER, ISACTIVE) 
VALUES
    ('gold_tables', 'EMPLOYEE', 'staging', 'employee', 'etl.usp_full_load_employee', 'SCD1', 1, 1),
    ('gold_tables', 'DRIVER',   'staging', 'driver',   'etl.usp_full_load_driver',   'SCD1', 1, 1),
    ('gold_tables', 'TRUCK',    'staging', 'truck',    'etl.usp_full_load_truck',    'SCD1', 1, 1),
    ('gold_tables', 'CUSTOMER', 'staging', 'customer', 'etl.usp_full_load_customer', 'SCD2', 2, 1),
    ('gold_tables', 'PRODUCT',  'staging', 'product',  'etl.usp_full_load_product',  'SCD2', 2, 1),
    ('gold_tables', 'VENDOR',   'staging', 'vendor',   'etl.usp_full_load_vendor',   'SCD2', 2, 1),
    ('gold_tables', 'FACTTRIP', 'staging', 'facttrip', 'etl.usp_full_load_facttrip', 'FACT', 3, 1);
GO

-- =========================================================================
-- B. SEEDING THE BULK / INCREMENTAL LOAD CONTROL TABLE
-- =========================================================================
INSERT INTO etl.inc_load_control_table 
    (TARGET_SCHEMA, TABLENAME, STAGING_SCHEMA, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE, LOADORDER, ISACTIVE) 
VALUES
    ('gold_tables', 'EMPLOYEE', 'staging', 'employee', 'etl.usp_inc_load_employee', 'SCD1', 1, 1),
    ('gold_tables', 'DRIVER',   'staging', 'driver',   'etl.usp_inc_load_driver',   'SCD1', 1, 1),
    ('gold_tables', 'TRUCK',    'staging', 'truck',    'etl.usp_inc_load_truck',    'SCD1', 1, 1),
    ('gold_tables', 'CUSTOMER', 'staging', 'customer', 'etl.usp_inc_load_customer', 'SCD2', 2, 1),
    ('gold_tables', 'PRODUCT',  'staging', 'product',  'etl.usp_inc_load_product',  'SCD2', 2, 1),
    ('gold_tables', 'VENDOR',   'staging', 'vendor',   'etl.usp_inc_load_vendor',   'SCD2', 2, 1),
    ('gold_tables', 'FACTTRIP', 'staging', 'facttrip', 'etl.usp_inc_load_facttrip', 'FACT', 3, 1);
GO
