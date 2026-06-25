
### --------------------------------------------------------------------------

## GOLD ADLS GEN2 → SQL SERVER STAGING → DIMENSION TABLES

### --------------------------------------------------------------------------

#### Database Architecture Map

        [OLAPDB]
         ├── staging               --> Raw landing zone (Always Truncate/Reload pattern)
         │    ├── employee, driver, truck, customer, product, vendor, facttrip
         ├── gold_tables           --> Production Dimensional Modeling (Star Schema)
         │    ├── dim_employee, dim_driver, dim_truck
         │    ├── dim_customer, dim_product, dim_vendor
         │    └── fact_trip
         ├── etl                   --> Control plane configurations & code assets
         │    ├── full_load_control_table
         │    ├── inc_load_control_table
         │    ├── (7) Full load stored procedures
         │    └── (7) Incremental load stored procedures
         └── gold_log              --> Operational logs & watermark boundaries
              └── watermark_table
# The Corrected, Step-by-Step Deployment Guide

## STEP 1: Deploy Database Schema Structures
        Script File: 01_ddl_schemas.sql
        Purpose: Create the isolated core database logical namespaces: staging, gold_tables, etl, and gold_log.

## STEP 2: Initialize Warehouse Infrastructure Logs
        Script File: 02_ddl_log_and_control_tables.sql
        Purpose: Create gold_log.watermark_table, etl.full_load_control_table, and etl.inc_load_control_table.         Seed them with the exact execution priority orders (LOADORDER 1, 2, and 3).

## STEP 3: STEP 3: Deploy Production Star Schema Tables
        Script File: 03_ddl_gold_star_schema.sql
        Purpose: Establish the core target physical layer: the 3 SCD1 tables, 3 SCD2 tables, and the primary           Fact table containing foreign keys.

## STEP 4: Seed Default Missing Dimension Members
        Script File: identity_updates.sql
        Purpose: Enforce identity insertions to insert default -1 rows (Missing Employee, Missing Customer,            etc.) into your 6 active dimensions. This step must happen here, otherwise, your foreign keys will             block subsequent full-load testing.

## STEP 5: Deploy High-Speed Staging Environment
        Script File: 05_ddl_staging_tables.sql
        Purpose: Generate the transient landing layer designed to host both full history and daily files.


## STEP 6: Deploy Full Load Stored Procedures
        CREATE ALL BULK/FULL LOAD PROCEDURES WITH UPDATING THE WATERMARK TABLES
        FILE NAMES 
                        full_load_customer.sql
                        full_load_driver.sql
                        full_load_employee.sql
                        full_load_product.sql
                        full_load_truck.sql
                        full_load_vendor.sql
                        full_load_facttrip.sql

## STEP 7: Deploy Multi-Row Incremental Stored Procedures
        CREATE ALL INCREMENTAL LOAD PROCEDURES WITH UPDATING THE WATERMARK TABLES
        FILE NAMES 
                        incload_scd1_emp_driver_truck.sql
                        incload_scd2_cust_prd_ven.sql
                        incload_fact.sql

# Azure Data Factory Orchestration BlueprintsSTEP 
## STEP 8: Configure Phase A — The Full Load Pipeline (PL_ORCHESTRATOR_FULL)
        1. Outer Ring Lookup: SELECT DISTINCT LOADORDER FROM etl.full_load_control_table WHERE ISACTIVE = 1 ORDER BY LOADORDER ASC;
        2. Sequential ForEach Container: Loops through layers 1, 2, and 3 step-by-step.
        3. Inner Matrix Lookup: SELECT * FROM etl.full_load_control_table WHERE LOADORDER = @{item().LOADORDER} AND ISACTIVE = 1;
        4. Parallel ForEach Container: Executes concurrently for all items in the current tier:
                Task 1: Execute Pre-Copy SQL Script inside sink: 
                        TRUNCATE TABLE staging.@{item().STAGINGTABLENAME};
                Task 2: Copy Activity (ADLS Gold File Parquet/CSV $\rightarrow$ SQL Server Staging Table).
                Task 3: Stored Procedure Activity: 
                        Call @{item().PROCEDURENAME} and pass parameter @pipeline().TriggerTime.
                
## STEP 9: Configure Phase B — The Incremental Load Pipeline (PL_ORCHESTRATOR_INCREMENTAL)
        1. Outer Ring Lookup: SELECT DISTINCT LOADORDER FROM etl.inc_load_control_table WHERE ISACTIVE = 1 ORDER BY LOADORDER ASC;
        2. Sequential ForEach Container: Iterates through dependencies (SCD1 $\rightarrow$ SCD2 $\rightarrow$ FACT).Inner Matrix Lookup: SELECT * FROM etl.inc_load_control_table WHERE LOADORDER = @{item().LOADORDER} AND ISACTIVE = 1;
        3. Parallel ForEach Container: Executes concurrently across all active tier assets:
                Task 1: Lookup Activity to fetch historical checkpoint: 
                        SELECT LAST_WATERMARK_DATE FROM gold_log.watermark_table WHERE TABLENAME =                                     '@{item().TABLENAME}';
                Task 2: Copy Activity (ADLS Gold Delta $\rightarrow$ SQL Server Staging Table). Filter using                   the dynamic source query:
                        SELECT * FROM Source WHERE ModifiedDate         >'@{activity('GetWatermark').output.firstRow.LAST_WATERMARK_DATE}' AND ModifiedDate <= '@{pipeline().TriggerTime}'
               Task 3: Stored Procedure Activity: 
                       Run @{item().PROCEDURENAME}, passing @pipeline().TriggerTime to safely process changes and commit the new watermark window.
                Task 4: Post-Load Cleanup Script: 
                        TRUNCATE TABLE staging.@{item().STAGINGTABLENAME};
                
# Updated Final Architecture Flow

        Your final system flow diagram should be updated slightly to remove the mention of "Master Stored              Procedures" since ADF is handling the execution loop directly:Gold ADLS Gen2 Data Lake Storage
                             ↓
        Azure Data Factory Dynamic Orchestrator (Consuming Control Metadata)
                             ↓
        SQL Server Staging Tables (Temporary Truncate/Reload Landing)
                             ↓
        Granular Stored Procedures (SCD1 MERGE / SCD2 LEAD Timelines / Fact Idempotency)
                             ↓
        SQL Server Production Analytics Tables (Clean Star Schema dimensions & facts)
                             ↓
        Power BI DirectQuery / Import Model



