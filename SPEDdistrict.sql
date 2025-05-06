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
RankedData AS (
    SELECT
        inc.incident_id,
        chr(60) || 'a href=/admin/incidents/incidentlog.html?id=' || inc.incident_id || ' target=_blank' || chr(62) || inc.incident_id || chr(60) || '/a' || chr(62) AS incident_link,
        TO_CHAR(inc.incident_ts, 'MM-DD-YYYY') AS incident_ts,
        stu.student_number,
        stu.id AS student_id,
        stu.dcid AS student_dcid,
        chr(60) || 'a href=/admin/students/home.html?frn=001' || stu.dcid || ' target=_blank' || chr(62) || stu.student_number || chr(60) || '/a' || chr(62) AS student_link,
        stu.state_studentnumber AS state_id,
        inc.incident_title,
        ilc.incident_category AS person_role,
        ilctype.incident_category,
        schools.abbreviation AS school_name, 
        created_teacher.lastfirst AS created_by_name,
        modified_teacher.lastfirst AS last_modified_by_name,
        TO_CHAR(act.action_plan_begin_dt, 'MM-DD-YYYY') AS action_plan_begin_dt,
        TO_CHAR(act.action_plan_end_dt, 'MM-DD-YYYY') AS action_plan_end_dt,
        act.duration_assigned,
        act.duration_actual,
        act.action_resolved_desc,
        CASE
            WHEN LOWER(ext.EL) IN ('frmr', 'former') THEN 'Former'
            WHEN LOWER(ext.EL) = 'no' THEN 'No'
            WHEN LOWER(ext.EL) = 'no-p' THEN 'No-P'
            WHEN LOWER(ext.EL) = 'ref' THEN 'Referral'
            WHEN LOWER(ext.EL) = 'yes' THEN 'Yes'
            WHEN LOWER(ext.EL) = 'yes-p' THEN 'Yes-P'
            ELSE 'Unknown'
        END AS english_learner_code,
        CASE
            WHEN LOWER(ext.SPED) = 'yes' THEN 'Yes'
            WHEN LOWER(ext.SPED) = 'no' THEN 'No'
            WHEN LOWER(ext.SPED) = 'ref' THEN 'Referral'
            ELSE 'Unknown'
        END AS sped_code,
        ROW_NUMBER() OVER (
            PARTITION BY inc.incident_id, stu.student_number
            ORDER BY act.action_plan_begin_dt DESC NULLS LAST
        ) AS row_num
    FROM
        incident inc
    JOIN incident_person_role ipr ON inc.incident_id = ipr.incident_id
    JOIN students stu ON ipr.studentid = stu.id
    LEFT JOIN U_DEF_EXT_STUDENTS ext ON stu.dcid = ext.STUDENTSDCID
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
            stu.student_number
        FROM
            students stu
        LEFT JOIN PS.S_MA_STU_SPED_X sped ON stu.dcid = sped.STUDENTSDCID
    ) sped ON stu.student_number = sped.student_number
    JOIN yearquery yq ON inc.incident_ts BETWEEN yq.FirstDay AND yq.LastDay
    WHERE
        inc.incident_ts BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')
)
SELECT
    student_link,
    state_id,
    sped_code,
    english_learner_code,
    incident_ts,
    incident_link,
    incident_title,
    person_role,
    incident_category,
    school_name, -- Abbreviation of the school name
    created_by_name,
    last_modified_by_name,
    action_plan_begin_dt,
    action_plan_end_dt,
    duration_assigned,
    duration_actual,
    action_resolved_desc
FROM RankedData
WHERE row_num = 1
ORDER BY
    incident_ts DESC,
    incident_id,
    student_number;

-- <th> for this report:
<th>Student Number</th>
<th>State ID</th>
<th>SPED Code</th>
<th>English Learner</th>
<th>Incident Date</th>
<th>Incident ID</th>
<th>Incident Title</th>
<th>Person Role</th>
<th>Incident Category</th>
<th>School Name</th>
<th>Created By</th>
<th>Last Modified By</th>
<th>Action Plan Begin Date</th>
<th>Action Plan End Date</th>
<th>Duration Assigned</th>
<th>Duration Actual</th>
<th>Action Resolved Description</th>
