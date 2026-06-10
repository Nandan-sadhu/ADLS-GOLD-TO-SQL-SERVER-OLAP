# ADLS-GOLD-TO-SQL-SERVER-OLAP
MOVING THE GOLD FACT AND DIMENTIONS TO OLAP FOR DATA WAREHOUSING AND ANALYTICS



## ASKING QUESTIONS TO SOURCE TEAM

### 1.BUISESNESS CONTEXT AND OWNERSHIP
  1.  WHO OWNS THE DATA                              --->  source team                  
  2.  THE BUISESNESS PROCESS IT SUPPORTS             --->  source oltp oracle moved to adls gen2 gold cleaned data
  3.  SYSTEM AND DATA DOCUMENTATIONS                 --->  provided the doc
  4.  DATA MODEL AND DATA CATALOG                    --->  er diagram, fact and dimention tables, the columns need to be ingested, along with source er, master, transactional etc

### 2. architecture and technology stack
  1.  HOW DATA IS STORED  --->  AZURE ADLS GEN2 CONTAINER
  2.  INTEGRATION CAPABLITY ---> LINKED SERVICES (USE THIS), API, DIRECT DB

### 3. EXTRACT AND LOAD
  1.  INCREMENTAL VS FULL  --->  FULL(5 YEARS) 1 YEAR AT A TIME OR FULL ONCE + INCREMENTAL
  2.  DATA SCOPE AND HISTORICAL NEEDS  --->  FOR SOME OF COLUMNS WE NEED TO HAVE UPSERT BUT SOME WE NEED HISTORICAL TRACKING SCD-1, SCD-2
  3.  EXPECTED SIZE OF EXTRACTS   ---> HISTORICAL(5TB), INCREMENTAL DAILY(5-10GB)
  4.  DATA VOLUME LIMITATIONS ---> ANY ?
  5.  HOW WE CAN AVOID IMPACT THE SOURCE SYSTEM PERFORMANCE  --->?
  6.  AUTONTICATION AND AUTORIZATION and security ---> token password,ip, key vault




#### THE FACT AND DIMENTION TABLES ARE ALLREADY CREATE IN ADLS, DIMENSION TABLES ARE RESULT JOIN OF MASTER AND OTHER TABLES, WE NEED TO LOAD THE DATA INTO TARGET AND DO THE DATA WAREHOUSING AND HISTORICAL TRACKING


## ABOUT THE DATA IN OLAP MASTER AND TRANSACTIONAL TMS DATA

CUST_DETAILS_CRM (M)	Core Clients: Defines your major corporate customers like Tata Steel or Jindal. This table stores billing terms, credit limits, and key tax data (GSTIN).

VEHICLES (TMS) (M)	The Fleet: This is the core inventory master. It manages your 300+ own trucks and active vendor trucks. It defines ownership (Own vs. Vendor) and physical capabilities (Capacity_Tons, Model_Year).

BRANCH_DETAILS (M)	Operational Footprint: Maps out your 12 primary hub locations and all their factory/mine-based sub-locations across India. This defines the geography of your business.

DRIVER_DETAILS_TMS (M)	Personnel: The definitive master roster for all personnel operating your vehicles. This table tracks who is on your staff and their current operational status (Active/Suspended).

VENDOR_DETAILS (M)	Partners: This table is essential for managing vendor trucks. It stores the details of the fleet providers, aggregators, and maintenance vendors that you utilize, along with critical tax data (PAN_Number).

CUST_ADDRESS_CRM (M)	Loading Locations: Since large customers have multiple operating sites, this master table maps specific plant gates, mine entrances, or port berths (e.g., Tata Steel Kalinganagar Gate 3).

TRUCK_INS_PERMIT (M)	Asset Compliance: Stores critical legal details—National Permits, Insurance Policies, and Fitness certificates—linked 1:1 to every operational vehicle to ensure they are road-legal.

DRIVER_LICENSCE_TMS (M)	Driver Compliance: Isolates mandatory licensing data—License Numbers, Badge Types (like HMV), and critical Expiry Dates—to prevent scheduling non-compliant drivers.

CUST_TYPE_CRM (M)	Customer Segmentation: A lookup table used to categorize customers by industry segment (e.g., Factories, Mining, Racks, Ports).

VEHICLE_MAINTENANCE (M)	Maintenance Schedule: While it tracks work (which can be a transactional log), in this schema, it is classified as (M) Master, likely representing maintenance plans, active work orders, or service registers rather than simple historic event logs.

EMPLOYEE_MASTER (M)	Internal Staff: The definitive register for internal company staff (Administrators, HR, Management), used for organizational tracking, department mapping, and likely linked to payroll functions.

DESIGNATION_MASTER (M)	Org Roles: A standardized organizational lookup defining corporate titles and roles across the entire enterprise.

DEPARTMENT (M)	Cost Centers: A master registry defining company divisions and departments, used to organize employees and track financial allocations per cost center.

![TMS ER DIAGRAM](images/TMS_ER.png)


