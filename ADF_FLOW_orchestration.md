
#### =======================================================
## DATA ARCHITECTURE & MULTI-TIER ETL ORCHESTRATION DOCUMENTATION
#### =======================================================
Target System: ADLS (Azure Data Lake Storage) Gold Layer to OLAP SQL Server
Pattern: Separated Metadata Controls with Internally-Managed Watermarks
Tools Used: Azure Data Factory (ADF), SQL Server Management Studio (SSMS)
Language Used: Transact-SQL (T-SQL)

DESCRIPTION:
Multiple master fact tables are joined together in ADLS for creating Fact and 
Dim tables. Further, these tables are loaded into the target SQL Server database 
to execute data warehousing operations and handle historical tracking (SCD1, SCD2).

#### =================================================
## 0. METADATA CONTROL TABLES DDL & SEED DATA LAYOUT
#### =================================================

0.1 CONTROL TABLE FOR FULL INITIAL LOADS
CREATE TABLE ETL.CONTROL_TABLE_FULL (
    TABLENAME VARCHAR(100),
    STAGINGTABLENAME VARCHAR(100),
    PROCEDURENAME VARCHAR(100),
    LOADTYPE VARCHAR(10),
    LOADORDER INT,
    ISACTIVE BIT
);

    -- Seed Data Layout (ETL.CONTROL_TABLE_FULL):
    -- TABLENAME     STAGINGTABLENAME   PROCEDURENAME                 LOADTYPE  LOADORDER  ISACTIVE
    -- --------------------------------------------------------------------------------------------
    -- EMPLOYEE      STG_EMPLOYEE       FULL_LOAD_EMPLOYEE            SCD1      1          1
    -- DRIVER        STG_DRIVER         FULL_LOAD_DRIVER              SCD1      1          1
    -- TRUCK         STG_TRUCK          FULL_LOAD_TRUCK               SCD1      1          1
    -- CUSTOMER      STG_CUSTOMER       FULL_LOAD_CUSTOMER            SCD2      2          1
    -- PRODUCT       STG_PRODUCT        FULL_LOAD_PRODUCT             SCD2      2          1
    -- VENDOR        STG_VENDOR         FULL_LOAD_VENDOR              SCD2      2          1
    -- FACTTRIP      STG_FACTTRIP       FULL_LOAD_FACTTRIP            FACT      3          1
    -- FACTSALES     STG_FACTSALES      FULL_LOAD_FACTSALES           FACT      3          1


0.2 CONTROL TABLE FOR INCREMENTAL / DELTA LOADS
CREATE TABLE ETL.CONTROL_TABLE_INCREMENTAL (
    TABLENAME VARCHAR(100),
    STAGINGTABLENAME VARCHAR(100),
    PROCEDURENAME VARCHAR(100),
    LOADTYPE VARCHAR(10),
    LOADORDER INT,
    ISACTIVE BIT
);

    -- Seed Data Layout (ETL.CONTROL_TABLE_INCREMENTAL):
    -- TABLENAME     STAGINGTABLENAME   PROCEDURENAME                 LOADTYPE  LOADORDER  ISACTIVE
    -- --------------------------------------------------------------------------------------------
    -- EMPLOYEE      STG_EMPLOYEE       INCREMENTAL_LOAD_EMPLOYEE     SCD1      1          1
    -- DRIVER        STG_DRIVER         INCREMENTAL_LOAD_DRIVER       SCD1      1          1
    -- TRUCK         STG_TRUCK          INCREMENTAL_LOAD_TRUCK        SCD1      1          1
    -- CUSTOMER      STG_CUSTOMER       INCREMENTAL_LOAD_CUSTOMER     SCD2      2          1
    -- PRODUCT       STG_PRODUCT        INCREMENTAL_LOAD_PRODUCT      SCD2      2          1
    -- VENDOR        STG_VENDOR         INCREMENTAL_LOAD_VENDOR       SCD2      2          1
    -- FACTTRIP      STG_FACTTRIP       INCREMENTAL_LOAD_FACTTRIP     FACT      3          1
    -- FACTSALES     STG_FACTSALES      INCREMENTAL_LOAD_FACTSALES    FACT      3          1


================================================================================
1. BULK COPY DESIGN PATTERN (PL_BULKLOAD_ALL)
================================================================================

#### 1.1 MAIN BULK COPY PIPELINE (PL_MAIN_ORCHESTRATOR_FULL)
1. LOOKUP ON FULL CONTROL TABLE ORDER BY LOAD ORDER
   SQL Query:
       SELECT DISTINCT LOADORDER 
       FROM ETL.CONTROL_TABLE_FULL 
       WHERE ISACTIVE = 1 
       ORDER BY LOADORDER;

   Sample Output JSON:
       [ {"LOADORDER": 1}, {"LOADORDER": 2}, {"LOADORDER": 3} ]

2. FOR EACH ACTIVITY [Settings -> Sequential = True]
   Expression: @activity('Lookup_LoadOrders').output.value
   Enforces: Order 1 finishes completely before Order 2 begins; Order 2 before Order 3.

3. EXECUTE PIPELINE ACTIVITY (Calls Child Pipeline per LoadOrder loop iteration)
   Invokes: PL_CHILD_LOAD_ORDER_FULL
   Pass Parameter: 
       LoadOrder = @item().LOADORDER


#### 1.2 CHILD PIPELINE (PL_CHILD_LOAD_ORDER_FULL)
Accepts Parameter: LoadOrder (Int)

1. LOOKUP TABLES FOR THE CURRENT LOAD ORDER
   SQL Query:
       SELECT TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE
       FROM ETL.CONTROL_TABLE_FULL
       WHERE LOADORDER = @{pipeline().parameters.LoadOrder}
       AND ISACTIVE = 1;

2. FOR EACH TABLE IN THE LOAD ORDER PARALLELLY [Settings -> Sequential = False]
   Expression: @activity('Lookup_Tables').output.value

3. EXECUTE PIPELINE ACTIVITY (Calls Grandchild Ingestion In Parallel)
   Invokes: PL_GRANDCHILD_TABLE_LOAD_FULL
   Pass Parameters: 
       TableName = @item().TABLENAME
       StageTableName = @item().STAGINGTABLENAME
       ProcedureName = @item().PROCEDURENAME
       LoadType = @item().LOADTYPE


#### 1.3 GRANDCHILD PIPELINE (PL_GRANDCHILD_TABLE_LOAD_FULL)
Accepts Parameters: TableName, StageTableName, ProcedureName, LoadType

1. SCRIPT ACTIVITY TO TRUNCATE STAGING TABLE
   SQL Script:
       TRUNCATE TABLE @{pipeline().parameters.StageTableName};

2. COPY ACTIVITY (FULL DATA INGESTION FROM ADLS TO STAGING)
   Source Dataset Query Expression:
       @concat('SELECT * FROM ', pipeline().parameters.TableName)
   Sink Dataset:
       Target Staging Table = @pipeline().parameters.StageTableName

3. EXECUTE STORED PROCEDURE (Loads Staging data into Target Core Production OLAP)
   Stored Procedure Name: @pipeline().parameters.ProcedureName
   *Note: This runs the "FULL_LOAD_TABLENAME" procedure.*


================================================================================
2. INCREMENTAL COPY DESIGN PATTERN (PL_INCREMENTAL_ALL)
================================================================================

#### 2.1 MAIN INCREMENTAL PIPELINE (PL_INCREMENTAL_ORCHESTRATOR)
1. LOOKUP ON INCREMENTAL CONTROL TABLE ORDER BY LOAD ORDER
   SQL Query:
       SELECT DISTINCT LOADORDER 
       FROM ETL.CONTROL_TABLE_INCREMENTAL 
       WHERE ISACTIVE = 1 
       ORDER BY LOADORDER;

2. FOR EACH ACTIVITY [Settings -> Sequential = True]
   Expression: @activity('Lookup_LoadOrders').output.value

3. EXECUTE PIPELINE ACTIVITY
   Invokes: PL_CHILD_LOAD_ORDER_INCREMENTAL
   Pass Parameter: 
       LoadOrder = @item().LOADORDER


#### 2.2 CHILD PIPELINE (PL_CHILD_LOAD_ORDER_INCREMENTAL)
Accepts Parameter: LoadOrder (Int)

1. LOOKUP TABLES FOR THE CURRENT LOAD ORDER
   SQL Query:
       SELECT TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE
       FROM ETL.CONTROL_TABLE_INCREMENTAL
       WHERE LOADORDER = @{pipeline().parameters.LoadOrder}
       AND ISACTIVE = 1;

2. FOR EACH TABLE IN THE LOAD ORDER PARALLELLY [Settings -> Sequential = False]
   Expression: @activity('Lookup_Tables').output.value

3. EXECUTE PIPELINE ACTIVITY (Calls Grandchild Ingestion In Parallel)
   Invokes: PL_GRANDCHILD_TABLE_LOAD_INCREMENTAL
   Pass Parameters: 
       TableName = @item().TABLENAME
       StageTableName = @item().STAGINGTABLENAME
       ProcedureName = @item().PROCEDURENAME
       LoadType = @item().LOADTYPE


#### 2.3 GRANDCHILD PIPELINE (PL_GRANDCHILD_TABLE_LOAD_INCREMENTAL)
Accepts Parameters: TableName, StageTableName, ProcedureName, LoadType

1. SCRIPT ACTIVITY TO TRUNCATE STAGING TABLE
   SQL Script:
       TRUNCATE TABLE @{pipeline().parameters.StageTableName};

2. LOOKUP THE WATERMARK TABLE TO ACQUIRE LAST COMPLETED TIMESTAMP
   SQL Query:
       SELECT WATERMARKDATE
       FROM GOLDLOG.WATERMARK_TABLE
       WHERE TABLENAME = '@{pipeline().parameters.TableName}';

3. SET VARIABLE (Cache Old Watermark Window Boundary Start)
   Variable: vWatermark
   Value: @activity('Lookup_Watermark').output.firstRow.WATERMARKDATE

4. SCRIPT ACTIVITY TO ACQUIRE MAX SOURCE DATETIME BEFORE EXTRACTION RUNS
   SQL Query:
       SELECT ISNULL(MAX(MODIFIEDDATE), GETDATE()) AS NEW_WATERMARK
       FROM @{pipeline().parameters.TableName};

5. SET VARIABLE (Cache New Watermark Window Boundary Ceiling)
   Variable: vNewWatermark
   Value: @activity('Lookup_NewWatermark').output.firstRow.NEW_WATERMARK

6. COPY ACTIVITY (STRICT BOUNDED DELTA EXTRACTION FROM ADLS TO STAGING)
   Source Dataset Query Expression:
       @concat('SELECT * FROM ', pipeline().parameters.TableName, ' WHERE MODIFIEDDATE > \'', variables('vWatermark'), '\' AND MODIFIEDDATE <= \'', variables('vNewWatermark'), '\'')
   Sink Dataset:
       Target Staging Table = @pipeline().parameters.StageTableName

7. EXECUTE STORED PROCEDURE (UPSERT / MERGE Delta into Destination Tables)
   Stored Procedure Name: @pipeline().parameters.ProcedureName
   Pass Stored Procedure Parameters (Optional but Recommended):
       @NewWatermarkDate = @variables('vNewWatermark')
   
   *CRITICAL DESIGN NOTE:*
   This executes the "INCREMENTAL_LOAD_TABLENAME" procedure. As per the 
   architecture, this Stored Procedure is solely responsible for internally 
   updating the 'GOLDLOG.WATERMARK_TABLE' value upon a successful table merge 
   transaction commit. No trailing ADF Script execution is required.
================================================================================
