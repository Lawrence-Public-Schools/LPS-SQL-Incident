-- Pulls the incident id, student id, and incident timestamp for all incidents that have a student id that is in the current selection of students.
WITH IncidentDetails AS (
    SELECT
        inc.incident_id,
        stu.student_number,
        inc.incident_ts,
        schools.name AS school_name,
        ilsc.long_desc AS incident_long_desc,
        ilctype.incident_category,
        created_teacher.lastfirst AS created_by_name, 
        modified_teacher.lastfirst AS last_modified_by_name 
    FROM
        students stu
        JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = stu.dcid
        JOIN incident_person_role ipr ON stu.id = ipr.studentid
        JOIN incident inc ON inc.incident_id = ipr.incident_id
        JOIN incident_detail id ON inc.incident_id = id.incident_id
        JOIN schools ON inc.school_number = schools.school_number
        JOIN incident_lu_code ilctype ON id.lu_code_id = ilctype.lu_code_id AND ilctype.code_type = 'incidenttypecode'
        JOIN incident_lu_sub_code ilsc ON id.lu_code_id = ilsc.lu_code_id AND id.lu_sub_code_id = ilsc.lu_sub_code_id
        LEFT JOIN teachers created_teacher ON inc.created_by = created_teacher.id 
        LEFT JOIN teachers modified_teacher ON inc.last_modified_by = modified_teacher.id 
),
LocationDetails AS (
    SELECT
        inc.incident_id,
        ilsclocation.long_desc AS location_description 
    FROM
        incident inc
        JOIN incident_detail idlocation ON inc.incident_id = idlocation.incident_id
        JOIN incident_lu_code ilclocation ON idlocation.lu_code_id = ilclocation.lu_code_id AND ilclocation.code_type = 'locationcode'
        JOIN incident_lu_sub_code ilsclocation ON idlocation.lu_code_id = ilsclocation.lu_code_id AND idlocation.lu_sub_code_id = ilsclocation.lu_sub_code_id
),
PersonRole AS (
    SELECT
        inc.incident_id,
        ilc.incident_category AS person_role 
    FROM
        students stu
        JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = stu.dcid
        JOIN incident_person_role ipr ON stu.id = ipr.studentid
        JOIN incident inc ON inc.incident_id = ipr.incident_id
        JOIN incident_detail ind ON ind.incident_detail_id = ipr.role_incident_detail_id
        JOIN incident_lu_code ilc ON ilc.lu_code_id = ind.lu_code_id
)
SELECT
    incd.incident_ts,
    chr(60) || 'a href=/admin/incidents/incidentlog.html?id=' || incd.incident_id || ' target=_blank' || chr(62) || incd.incident_id || chr(60) || '/a' || chr(62) AS incident_link,
    incd.student_number,
    pr.person_role,
    incd.incident_category,
    incd.school_name, 
    locd.location_description,
    incd.created_by_name,
    incd.last_modified_by_name
FROM
    IncidentDetails incd
    JOIN LocationDetails locd ON incd.incident_id = locd.incident_id
    JOIN PersonRole pr ON incd.incident_id = pr.incident_id
ORDER BY
    incd.student_number,
    incd.incident_id;

-- Columns to display in the result set:
<th>Incident Date</th>
<th>Incident ID</th>
<th>Student ID</th>
<th>Student Role</th>
<th>Incident Category</th>
<th>School Name</th>
<th>Location Description</th>
<th>Created By</th>
<th>Last Modified By</th>