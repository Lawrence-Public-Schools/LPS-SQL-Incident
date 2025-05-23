# LPS-SQL-Incident

## Overview

This project provides SQL queries for reporting student incidents at three levels:
- **currentSelection.sql**: Incidents for a selected group of students.
- **currentSchool.sql**: Incidents for all students in the currently selected school.
- **district.sql**: Incidents across the district within a date range.

All queries now use **Common Table Expressions (CTEs)** for clarity and maintainability.


## Key Differences Between Queries

| Query                | Student Filter                | Date Filter                          | Term Filter (CTE) |
|----------------------|------------------------------|--------------------------------------|-------------------|
| currentSelection.sql | Selected students only       | `%param1%` to `%param2%`             | No                |
| currentSchool.sql    | All in current school        | `%param1%` to `%param2%`             | No                |
| district.sql         | All students (district-wide) | `%param1%` to `%param2%` + term CTE  | Yes               |

- **currentSelection.sql**: Uses a temp table to filter by a specific student selection.
- **currentSchool.sql**: Filters by the current school ID.
- **district.sql**: Uses a `yearquery` CTE to filter by district-wide terms and applies a date range.

## Recent Updates

- **Refactored all queries to use CTEs** for modular and readable SQL.
- **Removed**: SPED primary disability, SPED level of education, and incident location description fields (see below for how to add them back).
- **Added**: `sped_code` and `el_code` fields for simplified SPED and EL status.
- **Action Taken Data**: Now included via CTEs and joined only for relevant student roles.
- **Date Filtering**: All queries use dynamic date range placeholders (`%param1%`, `%param2%`); only district-level queries also filter by term.


## Notes
**Retired fields:**
- SPED primary disability
- SPED level of education
- Incident location description

If you need to add these fields back, use a join and CASE statements as shown below:

```sql
-- SPED fields
LEFT JOIN PS.S_MA_STU_SPED_X sped ON stu.dcid = sped.STUDENTSDCID

sped.levelofneed AS levelofneed_code,
CASE
    WHEN sped.levelofneed IS NULL THEN 'No SPED Data'
    WHEN sped.levelofneed = '500' THEN 'Does not apply to student (500)'
    WHEN sped.levelofneed = '01' THEN 'Low - Less than 2 hours of service per week (01)'
    WHEN sped.levelofneed = '02' THEN 'Low - 2 hours or more of services per week (02)'
    WHEN sped.levelofneed = '03' THEN 'Moderate (03)'
    WHEN sped.levelofneed = '04' THEN 'High (04)'
    ELSE 'Unknown'
END AS levelofneed_label,
sped.primarydisability AS primarydisability_code,
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

-- Incident location description
JOIN incident_detail idlocation ON inc.incident_id = idlocation.incident_id
JOIN incident_lu_code ilclocation ON idlocation.lu_code_id = ilclocation.lu_code_id AND ilclocation.code_type = 'locationcode'
JOIN incident_lu_sub_code ilsclocation ON idlocation.lu_code_id = ilsclocation.lu_code_id AND idlocation.lu_sub_code_id = ilsclocation.lu_sub_code_id
ilsclocation.long_desc AS location_description
```