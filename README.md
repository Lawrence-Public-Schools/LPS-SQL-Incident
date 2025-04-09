# LPS-SQL-Incident

<!-- Add Documentation here -->

## Table of Contents

- [Overview](#overview)
- [Differences Between Queries](#differences-between-queries)
  - [currentSelection.sql](#currentselectionsql)
  - [currentSchool.sql](#currentschoolsql)
  - [district.sql](#districtsql)

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

---
<br>
<br>
<br>
<br>
<br>

# UPDATE: ADD THIS INTO THE README

## Investigation into SPED Table

### Key Findings

1. **Table Location**:
   - The `S_MA_STU_SPED_X` table is located in the `PS` schema as a **table** (`object_type = TABLE`).
   - Using **Data Export Manager** in the Students Core Table, we identified the following fields:
     - `STUDENTSDCID`, `alternativeeducation`, `levelofneed`, `primarydisability`, `sec504planstatus`, `sped3to5placement`, `sped6to21placement`, `spedevaluationresults`.

2. **Synonym Behavior**:
   - The `PS_MGMT` schema has a synonym `S_MA_STU_SPED_X` pointing to `PS.S_MA_STU_SPED_X`, allowing access from `PS_MGMT`.

3. **Data and Structure**:
   - Row counts and data from both `PS.S_MA_STU_SPED_X` and `PS_MGMT.S_MA_STU_SPED_X` are identical, confirming they access the same table.

---

### Why We Can't Use `students.levelofneed`

- The `S_MA_STU_SPED_X` table is a **table extension** of `students`, storing SPED-related fields separately.
- These fields are not part of the core `students` table and require a join:
  ```sql
  LEFT JOIN PS.S_MA_STU_SPED_X sped ON stu.dcid = sped.STUDENTSDCID
  ```

---

### Why We Use `PS.S_MA_STU_SPED_X`

- **Clarity**: Directly referencing `PS.S_MA_STU_SPED_X` avoids confusion about where the data resides.
- **Stability**: Avoids dependency on the `PS_MGMT` synonym, which could be removed or repointed.
- **Performance**: Direct access eliminates potential overhead from synonym resolution.

---

### Final Decision

We will use the direct reference to the table in the `PS` schema:
```sql
LEFT JOIN PS.S_MA_STU_SPED_X sped ON stu.dcid = sped.STUDENTSDCID
```

This ensures clarity, stability, and avoids potential issues with synonym dependencies.