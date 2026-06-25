
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
         FILE NAME DDL_SCHEMA.SQL

## STEP 1:

Create all **target dimension tables (DDL)** in SQL Server.
**SCD2 tables:**

    * surrogate_key
    * effective_start_date
    * effective_end_date
    * is_current

**SCD1 tables:**

    * optional surrogate_key
    * no history columns needed

---

## STEP 2:

Create **staging tables (DDL)** in SQL Server for every dimension table.

Purpose:
* Full load historical data
* Incremental daily data

Pattern:
* TRUNCATE
* RELOAD

---

## STEP 3:

Create **watermark table**.

Columns:

    * table_name
    * watermark_column
    * last_watermark_date
    * load_status
    * updated_date

---

## STEP 4:

ADF **Full Load Copy Activity**

Gold ADLS (5 years historical)
↓
SQL Server Staging Tables

Load all historical data.

---

## STEP 5:

Run **Full Load Stored Procedures**

### SCD2 Tables

Create historical SCD2 using:

    * LEAD()
    * LAG()
    * ROW_NUMBER()

Generate:

    * effective_start_date
    * effective_end_date
    * is_current

### SCD1 Tables

    Simple insert from staging → dimension. MERGE LOGIC

---

## STEP 6:

Create **Master Full Load Stored Procedure**

Example:

    EXEC all SCD1 full load procedures
    EXEC all SCD2 full load procedures

ADF calls:

    EXEC usp_master_full_load

---

## STEP 7:

ADF **Incremental Copy Activity**

Read watermark table.
Filter:
modified_date > watermark_date
Gold Incremental Data
↓
SQL Staging Tables

Before load:
TRUNCATE staging tables

---

## STEP 8:

Run **Incremental Stored Procedures**

### SCD2 Tables

If tracked columns changed:

    1. Expire old row
       is_current = 'N'
       effective_end_date = GETDATE()

    2. Insert new row
       is_current = 'Y'
       effective_start_date = GETDATE()

### SCD1 Tables

MERGE logic:

    WHEN MATCHED → UPDATE
    WHEN NOT MATCHED → INSERT

---

## STEP 9:

Create **Master Incremental Stored Procedure**

Execute all:

    * SCD1 incremental procedures
    * SCD2 incremental procedures

ADF calls:

    EXEC usp_master_incremental_load

---

## STEP 10:

Update **watermark table**

Only after successful incremental load.
Set:
last_watermark_date = MAX(modified_date)

---

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

