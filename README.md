# ADLS-GOLD-TO-SQL-SERVER-OLAP
MOVING THE GOLD FACT AND DIMENTIONS TO OLAP FOR DATA WAREHOUSING AND ANALYTICS


#### MULTIPLE MASTER FACT TABLES ARE JOINED TOGETHER  IN ADLS FOR CREATING FACT AND DIM TABLES , FURTHER THESE TABLES ARE LOADED INTO TARGET SQL SERVER AND DO THE DATA WAREHOUSING AND HISTORICAL TRACKING


## DATA IN TMS OLTP SERVER ----> ADLS ALREADY DONE
### ER LOGICAL DIAGRAM FOR OPERATIONAL DATA
![TMS ER DIAGRAM](images/TMS_ER.png)

## OLAP ER DIAGRAM WE WANT TO ACHEAIVE
![OLAP ER DIAGRAM FOR TMS](images/OLAP_ER_FINAL.png)

## IN THIS PROJECT WE WILL COVER
✅ Fact table DDL using surrogate keys from both SCD1 + SCD2 dimensions
✅ Staging fact table
✅ Full load stored procedure
✅ Incremental load with watermark
✅ Surrogate key lookup logic
✅ Handling SCD2 current record (IsCurrent = 1)
✅ MERGE logic for fact incremental
✅ BULKLOADALL stored procedure
✅ INCREMENTALLOADALL stored procedure
✅ Correct execution order (dimensions → facts)
✅ Sample source + incremental data
✅ End-to-end explanations and screenshot checklist
✅ Production-ready SQL Server code in Word format

## TOOLS USED
AZURE DATA FACTORY
SSMS

## LANGUAGE USED FOR THE WAREHOUSING
SQL

## LOGIC
ADF
ACTIVITY USED--> LOOKUP, FOREACH, EXECTUTE PIPELINE, LOOKUP,SET VARIABLE, COPY, STORED PROCEDURE
#### ------------------------------------------------------------------------------------------------
## BULK COPY

    [MAIN PIPELINE]
      └── Lookup: Get Distinct Active LOADORDERs
            └── ForEach (SEQUENTIAL = TRUE) -> Loops 1, then 2, then 3
                  └── Execute Child Pipeline (Passes current LOADORDER)

    [CHILD PIPELINE 1: LOAD ORDER LEVEL]
      └── Lookup: Get all Tables where LOADORDER = @pipeline().parameters.LoadOrder
            └── ForEach (SEQUENTIAL = FALSE) -> Runs tables in parallel (e.g., EMPLOYEE, DRIVER, TRUCK)
                  └── Execute Grandchild Pipeline (Passes TableMetadata)

    [GRANDCHILD PIPELINE: TABLE LEVEL]
      └── Truncate Staging Table (via Script activity)
      └── If Condition (Is Incremental?)
            ├── TRUE: Lookup Watermark -> Copy Delta Data (Source to Staging)
            └── FALSE: Copy All Data (Source to Staging)
      └── Execute Stored Procedure (Merge Staging to Production)
      └── Update Watermark Table (If incremental) ALLREADY DONE IN STORED PROCEDURE
  
### 1.) BULK COPY PIPELINE ONLY ONCE (PL_BULKLOAD_ALL)
CREATE A CONTROL TABLE CONTAINING COLUMNS

    TABLENAME,
    STAGINGTABLENAME,
    PROCEDURENAME,
    LOADORDER,
    LOADTYPE,
    ISACTIVE
    

       TABLENAME      STAGINGTABLENAME    PROCEDURENAME            LOADTYPE   LOADORDER  ISACTIVE
       ------------------------------------------------------------------------------------------------
            EMPLOYEE       STG_EMPLOYEE       FULL_LOAD_EMPLOYEE       SCD1       1          1
            DRIVER         STG_DRIVER         FULL_LOAD_DRIVER         SCD1       1          1
            TRUCK          STG_TRUCK          FULL_LOAD_TRUCK          SCD1       1          1

            CUSTOMER       STG_CUSTOMER       FULL_LOAD_CUSTOMER       SCD2       2          1
            PRODUCT        STG_PRODUCT        FULL_LOAD_PRODUCT       SCD2       2          1
            VENDOR         STG_VENDOR         FULL_LOAD_VENDOR         SCD2       2          1

            FACTTRIP       STG_FACTTRIP       FULL_LOAD_FACTTRIP       FACT       3          1
            FACTSALES      STG_FACTSALES      FULL_LOAD_FACTSALES      FACT       3          1


#### MAIN BULK COPY PIPELINE (PL_MAIN_ORCHESTRATOR)
1. LOOKUP ON CONTROL TABLE ORDER BY LOAD ORDER. THIS GIVES US THE CONROL TABLE CONTENTS ( SELECT DISTINCT LOADORDER FROM ETL.CONTROL_TABLE WHERE ISACTIVE = 1 ORDER BY LOADORDER; )
    SAMPLE DATA

        [
         { "LOADORDER":1 },
         { "LOADORDER":2 },
         { "LOADORDER":3 }
        ]
        
   
2. FOR EACH ACTIVITY TO GO EACH ITEMS SEQUENTIALLY [SEQUENTIAL = TRUE] (  @activity('Lookup_LoadOrders').output.value )
    FOR EACH LOADORDER
        Order 1 must finish before Order 2 starts
        Order 2 must finish before Order 3 starts
    INSIDE LOAD ORDER
       CURRENT LOADITEM @item().LOADORDER

3. EXECUTE PIPELINE ACTIVITY CALLING THE CHILD PIPELINE FOR THE CURRENT LOAD ORDER
    PASS PARAMETER: LoadOrder = @item().LOADORDER

#### CHILD PIPELINE RUN BY MAIN BULKPIPELINE ACCEPTS (LoadOrder) IN PARAMETERS
1. LOOKUP TABLES FOR CURRENT ORDER
   SQL SCRIPT:

       SELECT
          TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE
       FROM ETL.CONTROL_TABLE
       WHERE LOADORDER = @{pipeline().parameters.LoadOrder}
       AND ISACTIVE = 1;

   JSON VALUES EXAMPLE FOR SCD1 LOADORDER=1

       [
           {
             "TABLENAME":"EMPLOYEE",
             "STAGINGTABLENAME":"STG_EMPLOYEE",
             "PROCEDURENAME":"FULL_LOAD_EMPLOYEE",
             "LOADTYPE":"SCD1"
           },
           {
             "TABLENAME":"DRIVER",
             "STAGINGTABLENAME":"STG_DRIVER",
             "PROCEDURENAME":"FULL_LOAD_DRIVER",
             "LOADTYPE":"SCD1"
           }
       ]   
2. FOR EACH TABLE IN THAT LOADORDER PARALLELLY [SEQUENTIAL = FALSE] ( @activity('Lookup_Tables').output.value )

3. EXECUTE THE GRANDCHILD PIPELINE (FOR EACH TABLE RUN PARALLELY LOAD TABLES )
    PASS PARAMETERS: 
    TableName = @item().TABLENAME
    StageTableName = @item().STAGINGTABLENAME
    ProcedureName = @item().PROCEDURENAME
    LoadType = @item().LOADTYPE


#### GRANDCHILD PIPELINE RUN BY CHILD PIPELINE ACCEPTS (TableName, StageTableName, ProcedureName, LoadType) IN PARAMETERS
1. SCRIPT ACTIVITY TO CLEAN STAGING TABLE

       TRUNCATE TABLE @{pipeline().parameters.StageTableName};
2. LOOKUP THE WATERMARK TABLE

       SELECT WATERMARKDATE
       FROM GOLDLOG.WATERMARK_TABLE
       WHERE TABLENAME =
       '@{pipeline().parameters.TableName}'

3. SET VARIABLE PUT THIS WATERMARK DATE IN VARIABLE

       vWatermark = @activity('Lookup_Watermark').output.firstRow.WATERMARKDATE

4. COPY ACTIVITY COPY TO STAGING TABLE
   SOURCE
   
       SELECT *
       FROM @{pipeline().parameters.TableName}
       WHERE MODIFIEDDATE >
       '@{variables('vWatermark')}'
   SINK STAGINGTABLE

       @{pipeline().parameters.StageTableName}

5. EXECTUTE STORED PROCEDURE

       @{pipeline().parameters.ProcedureName}

7. SCRIPT ACTIVITY TO UPDATE THE WATERMARK TABLE

       UPDATE GOLDLOG.WATERMARK_TABLE
       SET WATERMARKDATE = GETDATE()
       WHERE TABLENAME = '@{pipeline().parameters.TableName}';

#### ---------------------------------------------------------------------------------------

### 1.) INCREMENTAL LOAD PIPELINE CONTROLS (PL_INCREMENTAL_ALL)
CREATE A CONTROL TABLE CONTAINING COLUMNS

    TABLENAME,
    STAGINGTABLENAME,
    PROCEDURENAME,
    LOADORDER,
    LOADTYPE,
    ISACTIVE
    

       TABLENAME      STAGINGTABLENAME    PROCEDURENAME                 LOADTYPE   LOADORDER  ISACTIVE
       --------------------------------------------------------------------------------------------------
            EMPLOYEE       STG_EMPLOYEE       INCREMENTAL_LOAD_EMPLOYEE     SCD1       1          1
            DRIVER         STG_DRIVER         INCREMENTAL_LOAD_DRIVER       SCD1       1          1
            TRUCK          STG_TRUCK          INCREMENTAL_LOAD_TRUCK        SCD1       1          1

            CUSTOMER       STG_CUSTOMER       INCREMENTAL_LOAD_CUSTOMER     SCD2       2          1
            PRODUCT        STG_PRODUCT        INCREMENTAL_LOAD_PRODUCT      SCD2       2          1
            VENDOR         STG_VENDOR         INCREMENTAL_LOAD_VENDOR       SCD2       2          1

            FACTTRIP       STG_FACTTRIP       INCREMENTAL_LOAD_FACTTRIP     FACT       3          1
            FACTSALES      STG_FACTSALES      INCREMENTAL_LOAD_FACTSALES    FACT       3          1
            
#### MAIN INCREMENTAL PIPELINE (PL_INCREMENTAL_ORCHESTRATOR)
1. LOOKUP ON CONTROL TABLE ORDER BY LOAD ORDER. THIS GIVES US THE CONROL TABLE CONTENTS ( SELECT DISTINCT LOADORDER FROM ETL.CONTROL_TABLE WHERE ISACTIVE = 1 ORDER BY LOADORDER; )
    SAMPLE DATA

        [
         { "LOADORDER":1 },
         { "LOADORDER":2 },
         { "LOADORDER":3 }
        ]
        
   
2. FOR EACH ACTIVITY TO GO EACH ITEMS SEQUENTIALLY [SEQUENTIAL = TRUE] (  @activity('Lookup_LoadOrders').output.value )
    FOR EACH LOADORDER
        Order 1 must finish before Order 2 starts
        Order 2 must finish before Order 3 starts
    INSIDE LOAD ORDER
       CURRENT LOADITEM @item().LOADORDER

3. EXECUTE PIPELINE ACTIVITY CALLING THE CHILD PIPELINE FOR THE CURRENT LOAD ORDER
    PASS PARAMETER: LoadOrder = @item().LOADORDER


#### CHILD PIPELINE RUN BY MAIN INCREMENTAL PIPELINE ACCEPTS (LoadOrder) IN PARAMETERS
1. LOOKUP TABLES FOR CURRENT ORDER
   SQL SCRIPT:

       SELECT
          TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE
       FROM ETL.CONTROL_TABLE
       WHERE LOADORDER = @{pipeline().parameters.LoadOrder}
       AND ISACTIVE = 1;

   JSON VALUES EXAMPLE FOR SCD1 LOADORDER=1

       [
           {
             "TABLENAME":"EMPLOYEE",
             "STAGINGTABLENAME":"STG_EMPLOYEE",
             "PROCEDURENAME":"INCREMENTAL_LOAD_EMPLOYEE",
             "LOADTYPE":"SCD1"
           },
           {
             "TABLENAME":"DRIVER",
             "STAGINGTABLENAME":"STG_DRIVER",
             "PROCEDURENAME":"INCREMENTAL_LOAD_DRIVER",
             "LOADTYPE":"SCD1"
           }
       ]

2. FOR EACH TABLE IN THAT LOADORDER PARALLELLY [SEQUENTIAL = FALSE] ( @activity('Lookup_Tables').output.value )

3. EXECUTE THE GRANDCHILD PIPELINE (FOR EACH TABLE RUN PARALLELY LOAD TABLES )
    PASS PARAMETERS: 
    TableName = @item().TABLENAME
    StageTableName = @item().STAGINGTABLENAME
    ProcedureName = @item().PROCEDURENAME
    LoadType = @item().LOADTYPE


#### GRANDCHILD PIPELINE RUN BY CHILD PIPELINE ACCEPTS (TableName, StageTableName, ProcedureName, LoadType) IN PARAMETERS
1. SCRIPT ACTIVITY TO CLEAN STAGING TABLE

       TRUNCATE TABLE @{pipeline().parameters.StageTableName};

2. LOOKUP THE WATERMARK TABLE TO GET THE LAST SUCCESSFUL RUN TIMESTAMP

       SELECT WATERMARKDATE
       FROM GOLDLOG.WATERMARK_TABLE
       WHERE TABLENAME =
       '@{pipeline().parameters.TableName}'

3. SET VARIABLE PUT THIS WATERMARK DATE IN VARIABLE

       vWatermark = @activity('Lookup_Watermark').output.firstRow.WATERMARKDATE

4. SCRIPT ACTIVITY TO FETCH THE MAX SOURCE DATE BEFORE EXTRACTION (PREVENTS DATA LOSS ON LONG RUNS)

       SELECT MAX(MODIFIEDDATE) AS NEW_WATERMARK
       FROM @{pipeline().parameters.TableName};

5. SET VARIABLE PUT THIS NEW RUN TIME IN VARIABLE

       vNewWatermark = @activity('Lookup_NewWatermark').output.firstRow.NEW_WATERMARK

6. COPY ACTIVITY COPY TO STAGING TABLE (DELTA FETCH ONLY)
   SOURCE
   
       SELECT *
       FROM @{pipeline().parameters.TableName}
       WHERE MODIFIEDDATE > '@{variables('vWatermark')}'
       AND MODIFIEDDATE <= '@{variables('vNewWatermark')}'
       
   SINK STAGINGTABLE

       @{pipeline().parameters.StageTableName}

7. EXECTUTE STORED PROCEDURE (UPSERT / MERGE STAGING DELTA INTO TARGET PRODUCTION OLAP)

       @{pipeline().parameters.ProcedureName}

8. SCRIPT ACTIVITY TO UPDATE THE WATERMARK TABLE TO THE COMPLETED RUN MARKER

       UPDATE GOLDLOG.WATERMARK_TABLE
       SET WATERMARKDATE = '@{variables('vNewWatermark')}'
       WHERE TABLENAME = '@{pipeline().parameters.TableName}';
