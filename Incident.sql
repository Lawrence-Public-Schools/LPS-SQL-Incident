-- Pulls the incident id, student id, and incident timestamp for all incidents that have a student id that is in the current selection of students.
SELECT
    chr(60) || 'a href=/admin/incidents/incidentlog.html?id=' || inc.incident_id || ' target=_blank' || chr(62) || inc.incident_id || chr(60) || '/a' || chr(62), 
    stu.student_number,
    inc.incident_ts,
    schools.name,
    ilc.incident_category
FROM
	students stu
	JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = stu.dcid
    JOIN incident_person_role ipr on stu.id = ipr.studentid
    JOIN incident inc ON inc.incident_id = ipr.incident_id
    JOIN students ON students.id = ipr.studentid
    JOIN schools ON inc.school_number = schools.school_number
    JOIN incident_detail ind ON ind.incident_detail_id = ipr.role_incident_detail_id
    JOIN incident_lu_code ilc ON ilc.lu_code_id = ind.lu_code_id
ORDER BY
	stu.student_number,
    inc.incident_id;

-- Columns to display in the result set:
<th>Incident ID</th>
<th>Student ID</th>
<th>Incident Timestamp</th>
<th>School</th>
<th>Role</th>