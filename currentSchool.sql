-- Big Query using the current school selected
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
        JOIN incident_person_role ipr ON stu.id = ipr.studentid
        JOIN incident inc ON inc.incident_id = ipr.incident_id
        JOIN incident_detail id ON inc.incident_id = id.incident_id
        JOIN schools ON inc.school_number = schools.school_number
        JOIN incident_lu_code ilctype ON id.lu_code_id = ilctype.lu_code_id AND ilctype.code_type = 'incidenttypecode'
        JOIN incident_lu_sub_code ilsc ON id.lu_code_id = ilsc.lu_code_id AND id.lu_sub_code_id = ilsc.lu_sub_code_id
        LEFT JOIN teachers created_teacher ON inc.created_by = created_teacher.id 
        LEFT JOIN teachers modified_teacher ON inc.last_modified_by = modified_teacher.id 
    WHERE
        stu.schoolid = ~(curschoolid) -- Filter by the current school
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
        stu.student_number,
        ilc.incident_category AS person_role,
        ROW_NUMBER() OVER (PARTITION BY inc.incident_id, stu.student_number ORDER BY 
            CASE 
                WHEN ilc.incident_category = 'Offender' THEN 1
                WHEN ilc.incident_category = 'Victim' THEN 2
                ELSE 3
            END) AS role_priority
    FROM
        students stu
        JOIN incident_person_role ipr ON stu.id = ipr.studentid
        JOIN incident inc ON inc.incident_id = ipr.incident_id
        JOIN incident_detail ind ON ind.incident_detail_id = ipr.role_incident_detail_id
        JOIN incident_lu_code ilc ON ilc.lu_code_id = ind.lu_code_id
    WHERE
        stu.schoolid = ~(curschoolid) -- Filter by the current school
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
    JOIN (
        SELECT incident_id, student_number, person_role
        FROM PersonRole
        WHERE role_priority = 1 -- Only keep the highest-priority role
    ) pr ON incd.incident_id = pr.incident_id AND incd.student_number = pr.student_number
ORDER BY
    incd.student_number,
    incd.incident_id;