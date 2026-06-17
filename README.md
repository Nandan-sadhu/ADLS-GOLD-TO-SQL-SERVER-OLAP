# ADLS-GOLD-TO-SQL-SERVER-OLAP
MOVING THE GOLD FACT AND DIMENTIONS TO OLAP FOR DATA WAREHOUSING AND ANALYTICS


#### MULTIPLE MASTER FACT TABLES ARE JOINED TOGETHER  IN ADLS FOR CREATING FACT AND DIM TABLES , FURTHER THESE TABLES ARE LOADED INTO TARGET SQL SERVER AND DO THE DATA WAREHOUSING AND HISTORICAL TRACKING


## DATA IN TMS OLAP SERVER ----> ADLS ALREADY DONE
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
### 1.) BULK COPY PIPELINE ONLY ONCE (PL_BULKLOAD_ALL)
CREATE A CONTROL TABLE CONTAINING COLUMNS

    TABLENAME,
    STAGINGTABLENAME,
    PROCEDURENAME,
    LOAD ORDER,
    LOADTYPE,
    ISACTIVE
   

       TABLENAME      STAGINGTABLENAME    PROCEDURENAME            LOADTYPE   LOADORDER  ISACTIVE
        ------------------------------------------------------------------------------------------------
            EMPLOYEE       STG_EMPLOYEE        FULL_LOAD_EMPLOYEE        SCD1       1          1
            DRIVER         STG_DRIVER          FULL_LOAD_DRIVER          SCD1       1          1
            TRUCK          STG_TRUCK           FULL_LOAD_TRUCK           SCD1       1          1

            CUSTOMER       STG_CUSTOMER        FULL_LOAD_CUSTOMER        SCD2       2          1
            PRODUCT        STG_PRODUCT         FULL_LOAD_PRODUCT         SCD2       2          1
            VENDOR         STG_VENDOR          FULL_LOAD_VENDOR          SCD2       2          1

            FACTTRIP       STG_FACTTRIP        FULL_LOAD_FACTTRIP        FACT       3          1
            FACTSALES      STG_FACTSALES       FULL_LOAD_FACTSALES       FACT       3          1
            
#### MAIN BULK COPY PIPELINE
1. LOOKUP ON CONTROL TABLE ORDER BY LOAD ORDER. THIS GIVES US THE CONROL TABLE CONTENTS ( SELECT DISTINCT LOADORDER FROM ETL.CONTROL_TABLE WHERE ISACTIVE = 1 ORDER BY LOADORDER; )
    SAMPLE DATA

        [
         { "LOADORDER":1 },
         { "LOADORDER":2 },
         { "LOADORDER":3 }
        ]
        
   
2. FOR EACH ACTIVITY TO GO EACH ITEMS PARALLELLY (  @activity('Lookup_LoadOrders').output.value )
    FOR EACH LOADORDER
        Order 1 must finish before Order 2 starts
        Order 2 must finish before Order 3 starts
   INSIDE LOAD OREDER
     CURRENT LOADITEM @item().LOADORDER

3. LOOKUP TABLES FOR CURRENT ORDER
   SQL SCRIPT:

       SELECT
          TABLENAME, STAGINGTABLENAME, PROCEDURENAME, LOADTYPE
       FROM ETL.CONTROL_TABLE
       WHERE LOADORDER = @{item().LOADORDER}
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
4. FOR EACH TABLE IN THAT LOADORDER ( @activity('Lookup_Tables').output.value )
     
5. EXECURE THE CHILD PIPELINE (FOR EACH LOAD ORDER, FOR EACH TABLE RUN PARALLELY LOAD TABLES )

#### CHILDPIPELINE RUN BY MAIN BULKPIPELINE ACCEPTS (TableName=@item().TABLENAME,  StageTableName=@item().STAGINGTABLENAME,  ProcedureName=@item().PROCEDURENAME,  LoadType=@item().LOADTYPE) IN PARAMETERS
1. COPY ACTIVITY DYNAMICALLY COPY TO THE STAGING TABLE  (STG_@{pipeline().parameters.TableName})
2. LOOKUP THE WATERMARK TABLE

       SELECT WATERMARKDATE
       FROM GOLDLOG.WATERMARK_TABLE
       WHERE TABLENAME =
       @{pipeline().parameters.TableName}
3. SET VARIABLE PUT THIS WATERMARK DATE IN VARIABLE

       vWatermark =@activity('Lookup_Watermark').output.firstRow.WATERMARKDATE
4. COPY ACTIVITY COPY TO STAGING TABLE
    SOURCE
   
       SELECT *
       FROM @{pipeline().parameters.TableName}
       WHERE MODIFIEDDATE >
       '@{variables('vWatermark')}'
   SINK STAGINGTABLE

       @{pipeline().parameters.StageTableName}
5.  EXECTUTE STORED PROCEDURE

         @{pipeline().parameters.ProcedureName}
        


