/* CHECK TRIAL BREEDING PROGRAM */
SELECT p.project_id AS project_id, p.name AS project_name, bp.name AS breeding_programs
FROM project_relationship AS bpr
LEFT JOIN project AS p ON (bpr.subject_project_id = p.project_id)
LEFT JOIN project AS bp ON (bpr.object_project_id = bp.project_id)
WHERE bpr.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'breeding_program_trial_relationship')
AND p.name LIKE 'SUWWSN%';

/* CHECK TRIAL FOLDER */
SELECT p.project_id AS project_id, p.name AS project_name, bp.name AS breeding_programs
FROM project_relationship AS bpr
LEFT JOIN project AS p ON (bpr.subject_project_id = p.project_id)
LEFT JOIN project AS bp ON (bpr.object_project_id = bp.project_id)
WHERE bpr.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'trial_folder')
AND p.name LIKE 'SUWWSN%';

/* UPDATE TRIAL BREEDING PROGRAM */
UPDATE project_relationship 
SET object_project_id = (SELECT project_id FROM project WHERE name = 'Winter Wheat Scab Nursery Cooperative')
WHERE subject_project_id IN (SELECT project_id FROM project WHERE name LIKE 'SUWWSN%')
AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'breeding_program_trial_relationship');

/* REMOVE TRIAL FROM FOLDER */
DELETE FROM project_relationship
WHERE subject_project_id IN (SELECT project_id FROM project WHERE name LIKE 'SUWWSN%')
AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'trial_folder');

/* ADD TRIAL TO FOLDER */
INSERT INTO project_relationship (subject_project_id, object_project_id, type_id) 
SELECT sp.project_id AS subject_project_id, op.project_id AS object_project_id, cvterm_id AS type_id
FROM project AS sp
LEFT JOIN project AS op ON (1=1)
LEFT JOIN cvterm ON (1=1)
WHERE sp.name LIKE 'SUWWSN%' 
AND op.name = 'Southern Uniform Winter Wheat Scab Nursery'
AND cvterm.name = 'trial_folder';
