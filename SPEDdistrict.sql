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
        lu_sub.LU_SUB_CODE_ID AS action_code, -- Action code from the lookup table
        lu_sub.SHORT_DESC AS action_short_desc, -- Short description from the lookup table
        lu_sub.LONG_DESC AS action_long_desc, -- Long description from the lookup table
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
            act.action_resolved_desc,
            act.INCIDENT_ACTION_ID AS action_code -- Use the correct column for action codes
        FROM
            PS.INCIDENT_ACTION act
    ) act ON inc.incident_id = act.incident_id
    LEFT JOIN INCIDENT_LU_SUB_CODE lu_sub ON act.action_code = lu_sub.LU_SUB_CODE_ID -- Join with lookup table
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
    action_resolved_desc,
    action_code, -- Include action code in final output
    action_short_desc, -- Include short description in final output
    action_code || ' - ' || COALESCE(action_short_desc, '') AS action_full_desc
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
<th>Action Code</th>
<th>Action Short Description</th>
<th>Action Long Description</th>





-- Works but repeats student and incident information for each action taken, as well as inconsistent data in the duration columns.
-- I think it is somewhat looping through the actions taken for each incident and student, which is why it is repeating.
-- I need to find a way to get the action taken for each incident and student without repeating the incident and student information.
SELECT
    stu.student_number,
    stu.state_studentnumber AS state_id,
    CASE
        WHEN LOWER(ext.SPED) = 'yes' THEN 'Yes'
        WHEN LOWER(ext.SPED) = 'no' THEN 'No'
        WHEN LOWER(ext.SPED) = 'ref' THEN 'Referral'
        ELSE 'Unknown'
    END AS sped_code,
    CASE
        WHEN LOWER(ext.EL) IN ('frmr', 'former') THEN 'Former'
        WHEN LOWER(ext.EL) = 'no' THEN 'No'
        WHEN LOWER(ext.EL) = 'no-p' THEN 'No-P'
        WHEN LOWER(ext.EL) = 'ref' THEN 'Referral'
        WHEN LOWER(ext.EL) = 'yes' THEN 'Yes'
        WHEN LOWER(ext.EL) = 'yes-p' THEN 'Yes-P'
        ELSE 'Unknown'
    END AS english_learner_code,
    TO_CHAR(inc.incident_ts, 'MM-DD-YYYY') AS incident_ts,
    inc.incident_id,
    inc.incident_title,
    ilc.incident_category AS person_role,
    ilctype.incident_category,
    schools.abbreviation AS school_name,
    created_teacher.lastfirst AS created_by_name,
    modified_teacher.lastfirst AS last_modified_by_name,
    act.action_plan_begin_dt,
    act.action_plan_end_dt,
    act.duration_assigned,
    act.duration_actual,
    act.action_resolved_desc,
    ind.lu_sub_code_id AS action_code,
    lu_sub.short_desc AS action_short_desc,
    lu_sub.long_desc AS action_long_desc
FROM
    incident_person_role ipr
    JOIN students stu ON ipr.studentid = stu.id
    LEFT JOIN U_DEF_EXT_STUDENTS ext ON stu.dcid = ext.STUDENTSDCID
    JOIN incident inc ON ipr.incident_id = inc.incident_id
    JOIN incident_detail ind ON ind.incident_id = ipr.incident_id
    LEFT JOIN incident_lu_sub_code lu_sub ON ind.lu_sub_code_id = lu_sub.lu_sub_code_id
    JOIN incident_lu_code ilc ON ind.lu_code_id = ilc.lu_code_id
    JOIN schools ON inc.school_number = schools.school_number
    JOIN incident_detail id ON inc.incident_id = id.incident_id
    JOIN incident_lu_code ilctype ON id.lu_code_id = ilctype.lu_code_id AND ilctype.code_type = 'incidenttypecode'
    LEFT JOIN teachers created_teacher ON inc.created_by = created_teacher.id
    LEFT JOIN teachers modified_teacher ON inc.last_modified_by = modified_teacher.id
    LEFT JOIN (
        SELECT
            act.incident_id,
            act.action_plan_begin_dt,
            act.action_plan_end_dt,
            act.duration_assigned,
            act.duration_actual,
            act.action_resolved_desc
        FROM
            PS.INCIDENT_ACTION act
    ) act ON inc.incident_id = act.incident_id
WHERE ind.lu_sub_code_id IN (
        1256, 100000, 100001, 100002, 100003, 100004, 100005, 100006,
        1255, 1254, 1253, 1352, 1351, 1551, 1550
    )
ORDER BY
    stu.student_number,
    ind.lu_sub_code_id;