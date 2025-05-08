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
        TO_CHAR(inc.incident_ts, 'MM-DD-YYYY') AS incident_ts,
        inc.school_number,
        inc.created_by,
        inc.last_modified_by
    FROM
        incident inc
    JOIN yearquery yq ON inc.incident_ts BETWEEN yq.FirstDay AND yq.LastDay
    -- WHERE
    --     inc.incident_id = 66144
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
        stu.schoolid
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
        -- lu_sub.long_desc AS action_long_desc
    FROM
        PS.INCIDENT_ACTION act
    JOIN incident_detail ind ON act.action_incident_detail_id = ind.incident_detail_id
    LEFT JOIN incident_lu_sub_code lu_sub ON ind.lu_sub_code_id = lu_sub.lu_sub_code_id
),
RankedResults AS (
    SELECT
        sb.student_number,
        sb.state_id,
        sb.student_lastfirst,
        ib.incident_id,
        ib.incident_ts,
        ib.incident_title,
        sch.abbreviation AS school_abbreviation,
        sp.sped_code,
        el.english_learner_code,
        ac.action_short_desc,
        role.person_role,
        ROW_NUMBER() OVER (
            PARTITION BY ib.incident_id, sb.student_number
            ORDER BY ac.action_short_desc DESC NULLS LAST
        ) AS row_num
    FROM
        incident_person_role ipr
        JOIN incident_base ib ON ipr.incident_id = ib.incident_id
        JOIN student_base sb ON ipr.studentid = sb.student_id
        JOIN schools sch ON ib.school_number = sch.school_number
        LEFT JOIN sped_cte sp ON sb.student_id = sp.student_id
        LEFT JOIN el_cte el ON sb.student_id = el.student_id
        LEFT JOIN role_cte role ON ib.incident_id = role.incident_id AND sb.student_id = role.student_id
        LEFT JOIN action_code_cte ac ON ib.incident_id = ac.incident_id
)
SELECT
    student_number,
    state_id,
    student_lastfirst,
    incident_id,
    incident_ts,
    incident_title,
    school_abbreviation,
    sped_code,
    english_learner_code,
    action_short_desc,
    person_role
FROM RankedResults
WHERE row_num = 1
ORDER BY
    student_number,
    state_id,
    incident_id,
    incident_ts,
    incident_title,
    school_abbreviation;