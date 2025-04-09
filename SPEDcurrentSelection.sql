-- SPEDcurrentSelection.sql
WITH RankedData AS (
    SELECT
        inc.incident_id,
        chr(60) || 'a href=/admin/incidents/incidentlog.html?id=' || inc.incident_id || ' target=_blank' || chr(62) || inc.incident_id || chr(60) || '/a' || chr(62) AS incident_link,
        inc.incident_ts,
        stu.student_number,
        stu.id AS student_id,
        stu.dcid AS student_dcid,
        chr(60) || 'a href=/admin/students/home.html?frn=001' || stu.dcid || ' target=_blank' || chr(62) || stu.student_number || chr(60) || '/a' || chr(62) AS student_link,
        inc.incident_title,
        ilc.incident_category AS person_role,
        ilctype.incident_category,
        schools.name AS school_name,
        created_teacher.lastfirst AS created_by_name,
        modified_teacher.lastfirst AS last_modified_by_name,
        CASE 
            WHEN ilc.incident_category = 'Offender' THEN act.action_plan_begin_dt
            ELSE NULL
        END AS action_plan_begin_dt,
        CASE 
            WHEN ilc.incident_category = 'Offender' THEN act.action_plan_end_dt
            ELSE NULL
        END AS action_plan_end_dt,
        CASE 
            WHEN ilc.incident_category = 'Offender' THEN act.duration_assigned
            ELSE NULL
        END AS duration_assigned,
        CASE 
            WHEN ilc.incident_category = 'Offender' THEN act.duration_actual
            ELSE NULL
        END AS duration_actual,
        CASE 
            WHEN ilc.incident_category = 'Offender' THEN act.action_resolved_desc
            ELSE NULL
        END AS action_resolved_desc,
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
        END AS primarydisability_label,
        ROW_NUMBER() OVER (
            PARTITION BY inc.incident_id, stu.student_number
            ORDER BY act.action_plan_begin_dt DESC NULLS LAST
        ) AS row_num
    FROM
        incident inc
    JOIN incident_person_role ipr ON inc.incident_id = ipr.incident_id
    JOIN students stu ON ipr.studentid = stu.id
    JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = stu.dcid
    JOIN incident_detail ind ON ipr.role_incident_detail_id = ind.incident_detail_id
    JOIN incident_lu_code ilc ON ind.lu_code_id = ilc.lu_code_id
    JOIN schools ON inc.school_number = schools.school_number
    JOIN incident_detail id ON inc.incident_id = id.incident_id
    JOIN incident_lu_code ilctype ON id.lu_code_id = ilctype.lu_code_id AND ilctype.code_type = 'incidenttypecode'
    LEFT JOIN teachers created_teacher ON inc.created_by = created_teacher.id
    LEFT JOIN teachers modified_teacher ON inc.last_modified_by = modified_teacher.id
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
    LEFT JOIN (
        SELECT
            stu.student_number,
            sped.levelofneed,
            sped.primarydisability
        FROM
            students stu
        LEFT JOIN PS.S_MA_STU_SPED_X sped ON stu.dcid = sped.STUDENTSDCID
    ) sped ON stu.student_number = sped.student_number
    WHERE
        inc.incident_ts BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')
)
SELECT
    incident_ts,
    incident_link,
    student_link,
    incident_title,
    person_role,
    incident_category,
    school_name,
    created_by_name,
    last_modified_by_name,
    action_plan_begin_dt,
    action_plan_end_dt,
    duration_assigned,
    duration_actual,
    action_resolved_desc,
    levelofneed_label,
    primarydisability_label
FROM RankedData
WHERE row_num = 1
ORDER BY
    incident_ts DESC,
    incident_id,
    student_number;