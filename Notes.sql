-- * Query for Incident Details
WITH IncidentDetails AS (
    SELECT
        inc.incident_id, -- The unique ID of the incident
        stu.student_number, -- The student involved in the incident
        inc.incident_ts, -- The timestamp of when the incident occurred
        schools.name AS school_name, -- The name of the school where the incident occurred
        ilsc.long_desc AS incident_long_desc, -- A detailed description of the incident
        ilctype.incident_category, -- The category of the incident (e.g., Bullying, Fighting)
        created_teacher.lastfirst AS created_by_name, -- The name of the user who created the incident
        modified_teacher.lastfirst AS last_modified_by_name -- The name of the user who last modified the incident
    FROM
        students stu
        JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = stu.dcid -- Filters students based on the current selection
        JOIN incident_person_role ipr ON stu.id = ipr.studentid -- Links students to their roles in incidents
        JOIN incident inc ON inc.incident_id = ipr.incident_id -- Links incidents to their details
        JOIN incident_detail id ON inc.incident_id = id.incident_id -- Links incidents to additional details
        JOIN schools ON inc.school_number = schools.school_number -- Links incidents to the school where they occurred
        JOIN incident_lu_code ilctype ON id.lu_code_id = ilctype.lu_code_id AND ilctype.code_type = 'incidenttypecode' -- Links incidents to their category
        JOIN incident_lu_sub_code ilsc ON id.lu_code_id = ilsc.lu_code_id AND id.lu_sub_code_id = ilsc.lu_sub_code_id -- Links incidents to their detailed description
        LEFT JOIN teachers created_teacher ON inc.created_by = created_teacher.id -- Links incidents to the user who created them
        LEFT JOIN teachers modified_teacher ON inc.last_modified_by = modified_teacher.id -- Links incidents to the user who last modified them
)



-- * Query for Location Details
LocationDetails AS (
    SELECT
        inc.incident_id, -- The unique ID of the incident
        ilsclocation.long_desc AS location_description -- The human-readable description of the location (e.g., Cafeteria, Hallway)
    FROM
        incident inc
        JOIN incident_detail idlocation ON inc.incident_id = idlocation.incident_id -- Links incidents to their details
        JOIN incident_lu_code ilclocation ON idlocation.lu_code_id = ilclocation.lu_code_id AND ilclocation.code_type = 'locationcode' -- Links incidents to their location code
        JOIN incident_lu_sub_code ilsclocation ON idlocation.lu_code_id = ilsclocation.lu_code_id AND idlocation.lu_sub_code_id = ilsclocation.lu_sub_code_id -- Links incidents to their detailed location description
)



-- * Query for Person Role Details
PersonRole AS (
    SELECT
        inc.incident_id, -- The unique ID of the incident
        ilc.incident_category AS person_role -- The role of the student in the incident
    FROM
        students stu
        JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = stu.dcid -- Filters students based on the current selection
        JOIN incident_person_role ipr ON stu.id = ipr.studentid -- Links students to their roles in incidents
        JOIN incident inc ON inc.incident_id = ipr.incident_id -- Links incidents to their details
        JOIN incident_detail ind ON ind.incident_detail_id = ipr.role_incident_detail_id -- Links incidents to additional details
        JOIN incident_lu_code ilc ON ilc.lu_code_id = ind.lu_code_id -- Links incidents to their role category
)


-- * Final Query to Display ALL Incident Details
SELECT
    incd.incident_ts, -- Incident timestamp
    chr(60) || 'a href=/admin/incidents/incidentlog.html?id=' || incd.incident_id || ' target=_blank' || chr(62) || incd.incident_id || chr(60) || '/a' || chr(62) AS incident_link, -- Incident link
    incd.student_number, -- Student number
    pr.person_role, -- Student role
    incd.incident_category, -- Incident category
    incd.school_name, -- School name
    locd.location_description, -- Location description
    incd.created_by_name, -- Name of the user who created the incident
    incd.last_modified_by_name -- Name of the user who last modified the incident
FROM
    IncidentDetails incd
    JOIN LocationDetails locd ON incd.incident_id = locd.incident_id
    JOIN PersonRole pr ON incd.incident_id = pr.incident_id
ORDER BY
    incd.student_number,
    incd.incident_id;