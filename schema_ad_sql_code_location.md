
### --------------------------------------------------------------------------

### GOLD ADLS GEN2 → SQL SERVER STAGING → DIMENSION TABLES

### (FULL LOAD + INCREMENTAL LOAD)

### --------------------------------------------------------------------------

#### [Database] consist of following schema
        ├── staging     --> raw landing area (Truncate/Reload)
             ├──
             ├──
             ├──
             ├──
        ├── gold_tables --> production analytics (Facts + Dimensions mixed)
             ├──
             ├──
             ├──
             ├──
        ├── etl         --> control records, execution configurations
             ├──   bulk_control_table
             ├──   incremental_contol_table
        └── gold_log    --> delta tracking, execution timestamps

## STEP 1: CREATING SCHEMA
         FILE NAME ddl_schema.sql

## STEP 2: CREATING ETL CONTOL TABLES WITH SEEDING THE PRIORITY ORDERS
         FILE NAME etl_contolable_priority.sql

## STEP 3: CREATING FACT AND DIM TABLES IN GOLD_TABLES SCHEMA
        FILE NAME ddl_fact_dim_tables.sql

## STEP 4: CREATE THE STAGING TABLES IN STAGING SCHEMA
        FILE NAME staging.sql 

        Purpose:
                * Full load historical data
                * Incremental daily data

        Pattern:
                * TRUNCATE
                * RELOAD

## STEP 5: CREATE ALL BULK/FULL LOAD PROCEDURES WITH UPDATING THE WATERMARK TABLES
        FILE NAMES 
                        full_load_customer.sql
                        full_load_driver.sql
                        full_load_employee.sql
                        full_load_product.sql
                        full_load_truck.sql
                        full_load_vendor.sql
                        full_load_facttrip.sql

## STEP 6: Essential Pre-Execution Step: Dimension Seeding
        Because we implemented your fallback -1 default tracking model, you must execute this script one time          to insert default rows into your active dimensions, or your fact table foreign keys will block                 execution.

        identity_update.sql

## STEP 5: CREATE ALL INCREMENTAL LOAD PROCEDURES WITH UPDATING THE WATERMARK TABLES
        FILE NAMES 
                        incload_scd1_emp_driver_truck.sql
                        incload_scd2_cust_prd_ven.sql
                        incload_fact.sql





## STEP 6: Phase A: The Full Load Pipeline (PL_ORCHESTRATOR_FULL)

        [ADF Lookup: Read Distinct LoadOrder] 
                 ↓
        [ForEach Activity: Loop through LoadOrder sequentially (1 -> 2 -> 3)]
                 ↓
        Inside the ForEach Container:
        [ADF Lookup: Fetch Tables & Procedures where LOADORDER = Current Index]
                 ↓
        [ForEach Activity (Parallel Mode Enabled): Run Tables Simultaneously]
                 ↓
        1. Clear Target Staging Table
        2. ADF Copy Activity: Stream file from ADLS Gold -> SQL Staging
        3. Stored Procedure Activity: Execute etl.usp_full_load_[TableName] 
           (Passes @pipeline().TriggerTime to handle internal watermarking)


## STEP 7: Phase B: The Incremental Load Pipeline (PL_ORCHESTRATOR_INCREMENTAL)

        [ADF Lookup: Read Distinct LoadOrder from etl.incremental_load_control_table]
                 ↓
        [ForEach Activity: Loop through LoadOrder sequentially (1 -> 2 -> 3)]
                 ↓
        Inside the ForEach Container:
        [ADF Lookup: Fetch Tables & Procedures where LOADORDER = Current Index]
                 ↓
        [ForEach Activity (Parallel Mode Enabled)]
                 ↓
        1. ADF Lookup: Get LAST_WATERMARK_DATE from gold_log.watermark_table
        2. ADF Copy Activity: Stream Delta from ADLS Gold -> SQL Staging 
           Filter: ModifiedDate > LastWatermark AND ModifiedDate <= PipelineTriggerTime
        3. Stored Procedure Activity: Execute etl.usp_inc_load_[TableName]
           (Executes Idempotent Upsert / SCD2 timeline split + updates Watermark internal to transaction)
        4. Truncate Staging Table (Clean up space)


## FINAL FLOW

Gold ADLS Gen2
↓
ADF Full / Incremental Copy
↓
SQL Staging Tables
↓
Master Stored Procedures
↓
SCD1 + SCD2 Logic
↓
SQL Server Dimension Tables
↓
Power BI

