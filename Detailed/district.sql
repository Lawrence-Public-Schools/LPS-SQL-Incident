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
incident_base AS (
    SELECT
        inc.incident_id,
        inc.incident_title,
        TO_CHAR(inc.incident_ts, 'YYYY-MM-DD') AS incident_ts,
        inc.incident_ts AS incident_ts_raw,
        inc.school_number,
        inc.created_by,
        inc.last_modified_by,
        ilctype.incident_category,
        act.action_resolved_desc
    FROM
        incident inc
    JOIN yearquery yq ON inc.incident_ts BETWEEN yq.FirstDay AND yq.LastDay
    JOIN incident_detail id ON inc.incident_id = id.incident_id
    JOIN incident_lu_code ilctype ON id.lu_code_id = ilctype.lu_code_id AND ilctype.code_type = 'incidenttypecode'
    LEFT JOIN (
        SELECT DISTINCT
            act.incident_id,
            act.action_resolved_desc
        FROM
            PS.INCIDENT_ACTION act
    ) act ON inc.incident_id = act.incident_id
    WHERE
        inc.incident_ts BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')
),
student_base AS (
    SELECT
        stu.id AS student_id,
        stu.student_number,
        stu.dcid,
        stu.state_studentnumber AS state_id,
        stu.lastfirst AS student_lastfirst,
        ext.SPED,
        ext.EL,
        stu.schoolid,
        stu.dob,
        stu.street,
        stu.city,
        stu.state,
        stu.zip
    FROM
        students stu
    LEFT JOIN U_DEF_EXT_STUDENTS ext ON stu.dcid = ext.STUDENTSDCID
),
sped_cte AS (
    SELECT
        stu.id AS student_id,
        CASE
            WHEN LOWER(ext.SPED) = 'yes' THEN 'Yes'
            WHEN LOWER(ext.SPED) = 'no' THEN 'No'
            WHEN LOWER(ext.SPED) = 'ref' THEN 'Referral'
            ELSE 'Unknown'
        END AS sped_code
    FROM
        students stu
    LEFT JOIN U_DEF_EXT_STUDENTS ext ON stu.dcid = ext.STUDENTSDCID
),
el_cte AS (
    SELECT
        stu.id AS student_id,
        CASE
            WHEN LOWER(ext.EL) IN ('frmr', 'former') THEN 'Former'
            WHEN LOWER(ext.EL) = 'no' THEN 'No'
            WHEN LOWER(ext.EL) = 'no-p' THEN 'No-P'
            WHEN LOWER(ext.EL) = 'ref' THEN 'Referral'
            WHEN LOWER(ext.EL) = 'yes' THEN 'Yes'
            WHEN LOWER(ext.EL) = 'yes-p' THEN 'Yes-P'
            ELSE 'Unknown'
        END AS english_learner_code
    FROM
        students stu
    LEFT JOIN U_DEF_EXT_STUDENTS ext ON stu.dcid = ext.STUDENTSDCID
),
role_cte AS (
    SELECT
        ipr.incident_id,
        ipr.studentid AS student_id,
        ilc.incident_category AS person_role
    FROM
        incident_person_role ipr
        JOIN incident_detail ind ON ipr.role_incident_detail_id = ind.incident_detail_id
        JOIN incident_lu_code ilc ON ind.lu_code_id = ilc.lu_code_id
),
action_code_cte AS (
    SELECT
        act.incident_id,
        ind.lu_sub_code_id AS action_code,
        lu_sub.short_desc AS action_short_desc
    FROM
        PS.INCIDENT_ACTION act
    JOIN incident_detail ind ON act.action_incident_detail_id = ind.incident_detail_id
    LEFT JOIN incident_lu_sub_code lu_sub ON ind.lu_sub_code_id = lu_sub.lu_sub_code_id
),
action_plan_cte AS (
    SELECT
        act.incident_id,
        TO_CHAR(act.action_plan_begin_dt, 'MM-DD-YYYY') AS action_plan_begin_dt,
        TO_CHAR(act.action_plan_end_dt, 'MM-DD-YYYY') AS action_plan_end_dt,
        act.duration_assigned,
        act.duration_actual
    FROM
        PS.INCIDENT_ACTION act
),
teachers_cte AS (
    SELECT id, lastfirst FROM teachers
),
student_contacts_cte AS (
    SELECT
        sb.dcid AS STUDENTDCID,
        COALESCE(NULLIF(MAX(CASE WHEN cs.DESCRIPTION = 'Mother' THEN p.LASTNAME || ', ' || p.FIRSTNAME END), ''), 'Guardian not listed') AS mother_name,
        COALESCE(NULLIF(MAX(CASE WHEN cs.DESCRIPTION = 'Father' THEN p.LASTNAME || ', ' || p.FIRSTNAME END), ''), 'Guardian not listed') AS father_name
    FROM student_base sb
    LEFT JOIN STUDENTCONTACTASSOC sca ON sb.dcid = sca.STUDENTDCID
    LEFT JOIN PERSON p ON p.ID = sca.PERSONID
    LEFT JOIN STUDENTCONTACTDETAIL scd ON sca.STUDENTCONTACTASSOCID = scd.STUDENTCONTACTASSOCID
    LEFT JOIN CODESET cs ON scd.RELATIONSHIPTYPECODESETID = cs.CODESETID
    GROUP BY sb.dcid
),
RankedResults AS (
    SELECT
        sb.student_number,
        sb.state_id,
        sb.student_lastfirst,
        sb.dcid,
        TO_CHAR(sb.dob, 'YYYY-MM-DD') AS dob,
        sb.street,
        sb.city,
        sb.state,
        sb.zip,
        sb.street || ', ' || sb.city || ', ' || sb.state || ' ' || sb.zip AS address_full,
        chr(60) || 'a href=/admin/incidents/incidentlog.html?id=' || ib.incident_id || ' target=_blank' || chr(62) || ib.incident_id || chr(60) || '/a' || chr(62) AS incident_link,
        chr(60) || 'a href=/admin/students/home.html?frn=001' || sb.dcid || ' target=_blank' || chr(62) || sb.student_number || chr(60) || '/a' || chr(62) AS student_link,
        ib.incident_ts,
        ib.incident_title,
        sch.abbreviation AS school_abbreviation,
        sp.sped_code,
        el.english_learner_code,
        ac.action_short_desc,
        COALESCE(TO_CHAR(ap.action_plan_begin_dt), 'N/A') AS action_plan_begin_dt,
        COALESCE(TO_CHAR(ap.action_plan_end_dt), 'N/A') AS action_plan_end_dt,
        COALESCE(TO_CHAR(ap.duration_assigned), 'N/A') AS duration_assigned,
        COALESCE(TO_CHAR(ap.duration_actual), 'N/A') AS duration_actual,
        role.person_role,
        ib.incident_category,
        COALESCE(ib.action_resolved_desc, 'N/A') AS action_resolved_desc,
        created_teacher.lastfirst AS created_by_name,
        modified_teacher.lastfirst AS last_modified_by_name,
        sc.mother_name,
        sc.father_name,
        ROW_NUMBER() OVER (
            PARTITION BY ib.incident_id, sb.student_number
            ORDER BY ac.action_short_desc DESC NULLS LAST
        ) AS row_num
    FROM
        incident_person_role ipr
        JOIN incident_base ib ON ipr.incident_id = ib.incident_id
        JOIN yearquery yq ON ib.incident_ts_raw BETWEEN yq.FirstDay AND yq.LastDay
        JOIN student_base sb ON ipr.studentid = sb.student_id
        JOIN schools sch ON ib.school_number = sch.school_number
        LEFT JOIN sped_cte sp ON sb.student_id = sp.student_id
        LEFT JOIN el_cte el ON sb.student_id = el.student_id
        LEFT JOIN role_cte role ON ib.incident_id = role.incident_id AND sb.student_id = role.student_id
        LEFT JOIN action_code_cte ac ON ib.incident_id = ac.incident_id
        LEFT JOIN action_plan_cte ap ON ib.incident_id = ap.incident_id
        LEFT JOIN teachers_cte created_teacher ON ib.created_by = created_teacher.id
        LEFT JOIN teachers_cte modified_teacher ON ib.last_modified_by = modified_teacher.id
        LEFT JOIN student_contacts_cte sc ON sb.dcid = sc.STUDENTDCID
    WHERE
        ib.incident_ts_raw BETWEEN TO_DATE('%param1%', '~[dateformat]') AND TO_DATE('%param2%', '~[dateformat]')
)
SELECT
    student_link,
    state_id,
    dob,
    student_lastfirst,
    mother_name,
    father_name,
    street,
    city,
    state,
    zip,
    address_full,
    sped_code,
    english_learner_code,
    incident_ts,
    incident_link,
    incident_title,
    person_role,
    action_short_desc,
    action_resolved_desc,
    incident_category,
    action_plan_begin_dt,
    action_plan_end_dt,
    duration_assigned,
    duration_actual,
    created_by_name,
    last_modified_by_name,
    school_abbreviation
FROM RankedResults
WHERE row_num = 1
ORDER BY
    incident_ts DESC,
    incident_link,
    incident_title,
    student_number,
    state_id,
    school_abbreviation;

-- <th> for this report
<th>Student Number</th>
<th>State ID</th>
<th>DOB</th>
<th>Student Name</th>
<th>Mother Name</th>
<th>Father Name</th>
<th>Street</th>
<th>City</th>
<th>State</th>
<th>Zip</th>
<th>Full Address</th>
<th>SPED</th>
<th>EL</th>
<th>Incident Date</th>
<th>Incident ID</th>
<th>Incident Title</th>
<th>Incident Role</th>
<th>Action Resolved</th>
<th>Action Code</th>
<th>Incident Category</th>
<th>Action Plan Begin Date</th>
<th>Action Plan End Date</th>
<th>Duration Assigned</th>
<th>Duration Actual</th>
<th>Created By</th>
<th>Last Modified By</th>
<th>School Abbreviation</th>