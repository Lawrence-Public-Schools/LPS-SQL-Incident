-- Pulls the incident id, student id, and incident timestamp for all incidents that have a student id that is in the current selection of students.
SELECT
    chr(60) || 'a href=/admin/incidents/incidentlog.html?id=' || inc.incident_id || ' target=_blank' || chr(62) || inc.incident_id || chr(60) || '/a' || chr(62), 
    ipr.studentid,
    inc.incident_ts
FROM
    incident_person_role ipr
    JOIN ~[temp.table.current.selection:students] stusel ON stusel.dcid = ipr.studentid
    JOIN incident inc ON inc.incident_id = ipr.incident_id
    JOIN students ON students.id = ipr.studentid
ORDER BY
    inc.incident_id;