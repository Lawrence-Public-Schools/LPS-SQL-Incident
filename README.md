# LPS-SQL-Incident

<!-- Add Documentation here -->

## Table of Contents

- [Overview](#overview)
- [Differences Between Queries](#differences-between-queries)
  - [currentSelection.sql](#currentselectionsql)
  - [currentSchool.sql](#currentschoolsql)
  - [district.sql](#districtsql)
- [UPDATES: Adding SPED, Action Taken Data and Date Range Filtering](#updates-adding-sped-action-taken-data-and-date-range-filtering)
  - [Accessing SPED Data](#accessing-sped-data)
  - [Accessing Action Taken Data](#accessing-action-taken-data)
  - [Date Range Filtering in Queries](#date-range-filtering-in-queries)

## Overview

All three queries retrieve incident details using Common Table Expressions (CTEs) to organize their logic into reusable components. However, they differ in their filtering criteria and intended use cases:

- **currentSelection.sql**: Focuses on incidents involving students in a pre-defined selection.
- **currentSchool.sql**: Filters incidents based on the currently selected school.
- **district.sql**: Retrieves incidents across the district within a specified date range and includes a `yearquery` CTE for term-based filtering.

## Differences Between Queries

### 1. currentSelection.sql

- **Purpose**: Retrieves incidents for students in a pre-defined selection.
- **Key Filtering**:
  - Uses a temporary table `~[temp.table.current.selection:students]` to filter students.
- **Scope**: Limited to the selected students.

  ```sql
  JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = stu.dcid
  ```

---

### 2. currentSchool.sql

- **Purpose**: Retrieves incidents for students in the currently selected school.
- **Key Filtering**:
  - Filters by `stu.schoolid = ~(curschoolid)` to limit results to the current school.
- **Scope**: Limited to the current school.

  ```sql
  WHERE stu.schoolid = ~(curschoolid)
  ```

---

### 3. district.sql

- **Purpose**: Retrieves incidents across the district within a specified date range.
- **Key Filtering**:
  - Filters by `inc.incident_ts BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')` to limit results to a date range.
  - Includes a `yearquery` CTE to filter terms where `portion = 1` and `schoolid = 0` (district-wide terms).
- **Scope**: District-wide, within the specified date range.
- **Use of CTEs**:

  - `yearquery`: Retrieves district-wide term details for filtering.
  - `IncidentDetails`: Retrieves incident details for the district.
  - `LocationDetails`: Retrieves location descriptions for incidents.
  - `PersonRole`: Assigns roles (e.g., Offender, Victim) to students in incidents.

School is set to 0 to include all schools in the district, then the `yearquery` CTE is used to filter terms where `portion = 1` and `schoolid = 0`:

```sql
      WITH yearquery AS (
      SELECT
          dcid,
          abbreviation,
          FirstDay,
          LastDay,
          schoolid
      FROM
          terms
      WHERE
          portion = 1
          AND schoolid = 0
  ),
```

Data is then filtered by the specified date range:

```sql
WHERE
  inc.incident_ts BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')
```
<br/>

## UPDATES: Adding SPED, Action Taken Data and Date Range Filtering

### Accessing SPED Data

1. **SPED Data Location**:
   - SPED-related data is stored in the `PS.S_MA_STU_SPED_X` table, which is a table extension of `students`.
   - This table includes fields such as:
     - `levelofneed`: Indicates the level of special education services required.
     - `primarydisability`: Specifies the primary disability of the student.

2. **Integration with Student Data**:
   - The `PS.S_MA_STU_SPED_X` table is joined with the `students` table using the `dcid` field:

     ```sql
     LEFT JOIN PS.S_MA_STU_SPED_X sped ON stu.dcid = sped.STUDENTSDCID
     ```

3. **Data and Structure**:
   - The `PS_MGMT` schema has a synonym `S_MA_STU_SPED_X` pointing to `PS.S_MA_STU_SPED_X`, allowing access from `PS_MGMT`.
   - Row counts and data from both `PS.S_MA_STU_SPED_X` and `PS_MGMT.S_MA_STU_SPED_X` are identical, confirming they access the same table.

4. **SPED Data Labels**:
   - The query uses `CASE` statements to provide human-readable labels for `levelofneed` and `primarydisability`:
     ```sql
     CASE
         WHEN sped.levelofneed IS NULL THEN 'No SPED Data'
         WHEN sped.levelofneed = '500' THEN 'Does not apply to student (500)'
         WHEN sped.levelofneed = '01' THEN 'Low - Less than 2 hours of service per week (01)'
         WHEN sped.levelofneed = '02' THEN 'Low - 2 hours or more of services per week (02)'
         WHEN sped.levelofneed = '03' THEN 'Moderate (03)'
         WHEN sped.levelofneed = '04' THEN 'High (04)'
         ELSE 'Unknown'
     END AS levelofneed_label,
     CASE
         WHEN sped.primarydisability IS NULL THEN 'No SPED Data'
         WHEN sped.primarydisability = '500' THEN 'Does not apply to student (500)'
         WHEN sped.primarydisability = '01' THEN 'Intellectual (01)'
         WHEN sped.primarydisability = '02' THEN 'Sensory/Hard of Hearing or Deaf (02)'
         WHEN sped.primarydisability = '03' THEN 'Communication (03)'
         WHEN sped.primarydisability = '04' THEN 'Sensory/Vision Impairment or Blind (04)'
         WHEN sped.primarydisability = '05' THEN 'Emotional (05)'
         WHEN sped.primarydisability = '06' THEN 'Physical (06)'
         WHEN sped.primarydisability = '07' THEN 'Health (07)'
         WHEN sped.primarydisability = '08' THEN 'Specific Learning Disabilities (08)'
         WHEN sped.primarydisability = '09' THEN 'Sensory/Deafblind (09)'
         WHEN sped.primarydisability = '10' THEN 'Multiple Disabilities (10)'
         WHEN sped.primarydisability = '11' THEN 'Autism (11)'
         WHEN sped.primarydisability = '12' THEN 'Neurological (12)'
         WHEN sped.primarydisability = '13' THEN 'Developmental Delay (13)'
         ELSE 'Unknown'
     END AS primarydisability_label
     ```

5. **Why We Can't Use `students.levelofneed`**:
   - The `S_MA_STU_SPED_X` table is a **table extension** of `students`, storing SPED-related fields separately.
   - These fields are not part of the core `students` table and require a join with `PS.S_MA_STU_SPED_X` to access them.


### Accessing Action Taken Data

1. **Action Data Location**:
   - The actions taken for incidents are stored in the `PS.INCIDENT_ACTION` table.
   - This table includes fields such as:
     - `action_plan_begin_dt`
     - `action_plan_end_dt`
     - `duration_assigned`
     - `duration_actual`
     - `action_resolved_desc`

2. **Integration with Incident Data**:
   - The `PS.INCIDENT_ACTION` table is joined with the `incident` table using the `incident_id` field:

     ```sql
     LEFT JOIN (
         SELECT DISTINCT
             act.incident_id,
             act.action_plan_begin_dt,
             act.action_plan_end_dt,
             act.duration_assigned,
             act.duration_actual,
             act.action_resolved_desc
         FROM
             PS.INCIDENT_ACTION act
     ) act ON inc.incident_id = act.incident_id
     ```

3. **Conditional Inclusion of Action Data**:
    - Action data is conditionally included in the query based on the role of the student in the incident:
    
      - If the student is an Offender, the action data is **included**.

      - For other roles, the action data is set to `NULL`:

       ```sql
       CASE 
           WHEN ilc.incident_category = 'Offender' THEN act.action_plan_begin_dt
           ELSE NULL -- Wanted to put "NA" but caused errors due to data type mismatch
       END AS action_plan_begin_dt,
       CASE 
           WHEN ilc.incident_category = 'Offender' THEN act.action_plan_end_dt
           ELSE NULL -- ^
       END AS action_plan_end_dt,
       CASE 
           WHEN ilc.incident_category = 'Offender' THEN act.duration_assigned
           ELSE NULL -- ^
       END AS duration_assigned,
       CASE 
           WHEN ilc.incident_category = 'Offender' THEN act.duration_actual
           ELSE NULL  -- ^
       END AS duration_actual,
       CASE 
           WHEN ilc.incident_category = 'Offender' THEN act.action_resolved_desc
           ELSE NULL -- Could have put "NA" since string, but decided to keep it NULL
       END AS action_resolved_desc
       ```

### Date Range Filtering in Queries

#### District-Level Queries (`district.sql` and `SPEDdistrict.sql`)

1. **Using `yearquery` for Term-Based Filtering**:
   - In district-level queries, the date range is determined by the `yearquery` Common Table Expression (CTE).
   - The `yearquery` CTE retrieves the start (`FirstDay`) and end (`LastDay`) dates for terms where:
     - `portion = 1`: Ensures only full terms are included.
     - `schoolid = 0`: Filters for district-wide terms.
   - Example:

     ```sql
     WITH yearquery AS (
         SELECT 
             dcid, 
             abbreviation, 
             FirstDay, 
             LastDay, 
             schoolid 
         FROM 
             terms 
         WHERE 
             portion = 1 
             AND schoolid = 0
     )
     ```

2. **Filtering Incidents by Term Dates**:
   - The `yearquery` CTE is joined with the `incident` table to filter incidents that occurred within the term dates:

     ```sql
     JOIN yearquery yq ON inc.incident_ts BETWEEN yq.FirstDay AND yq.LastDay
     ```

   - This ensures that only incidents within the district-wide term dates are included in the results.

3. **Additional Date Range Filtering**:
   - A secondary filter allows for dynamic date range selection using placeholders (`%param1%` and `%param2%`):

     ```sql
     WHERE
         inc.incident_ts BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')
     ```

   - This provides flexibility to narrow down the results further within the term dates.


#### Current Selection and Current School Queries (`currentSelection.sql` and `currentSchool.sql`)

1. **Direct Date Range Filtering**:
   - In these queries, the date range is applied directly to the `incident_ts` column using placeholders (`%param1%` and `%param2%`):
     ```sql
     WHERE
         inc.incident_ts BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')
     ```
   - This logic is shared between `currentSelection.sql` and `currentSchool.sql`.

2. **Dynamic Date Range**:
   - The placeholders `%param1%` and `%param2%` are replaced with actual date values during query execution.
   - The `~[dateformat]` placeholder ensures the dates are formatted correctly for the database.

3. **No Term-Based Filtering**:
   - Unlike district-level queries, these queries do not use the `yearquery` CTE. Instead, they rely solely on the provided date range for filtering.

### Summary of Differences

| Query Type                | Date Range Logic                                                                 | Term-Based Filtering |
|---------------------------|-----------------------------------------------------------------------------------|----------------------|
| **District-Level Queries** | Combines `yearquery` term dates with dynamic date range filtering (`%param1%`, `%param2%`). | Yes                  |
| **Current Selection/School** | Uses only dynamic date range filtering (`%param1%`, `%param2%`).                  | No                   |
