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
