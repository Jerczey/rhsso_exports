-- Objetivo 2: clientId en uso vs sin actividad — Microsoft SQL Server (RHSSO / Keycloak)
-- Ejemplo sqlcmd:
--   sqlcmd -S ${MSSQL_HOST},${MSSQL_PORT} -U ${MSSQL_USER} -P "${MSSQL_PASSWORD}" \
--     -d ${MSSQL_DB} -i client-usage-report_mssql.sql
-- O usar: DB_TYPE=mssql ./client-usage-report.sh

SET NOCOUNT ON;

PRINT '=== Client usage by realm (sessions, offline tokens, events) ===';

;WITH realm_clients AS (
  SELECT
    r.id   AS realm_id,
    r.name AS realm_name,
    c.id   AS client_internal_id,
    c.client_id,
    c.enabled,
    c.public_client,
    c.protocol
  FROM client c
  INNER JOIN realm r ON c.realm_id = r.id
),
active_sessions AS (
  SELECT
    c.realm_id,
    c.client_id,
    COUNT(*) AS active_sessions
  FROM client_session cs
  INNER JOIN user_session us ON cs.session_id = us.id
  INNER JOIN client c ON cs.client_id = c.id
  GROUP BY c.realm_id, c.client_id
),
offline_sessions AS (
  SELECT
    c.realm_id,
    c.client_id,
    COUNT(*) AS offline_sessions
  FROM offline_client_session ocs
  INNER JOIN client c ON ocs.client_id = c.id
  GROUP BY c.realm_id, c.client_id
),
user_events AS (
  SELECT
    e.realm_id,
    e.client_id,
    COUNT(*) AS user_events,
    MAX(e.event_time) AS last_user_event_ms
  FROM event_entity e
  WHERE e.client_id IS NOT NULL
  GROUP BY e.realm_id, e.client_id
),
realm_events_enabled AS (
  SELECT
    realm_id,
    MAX(CASE WHEN name = 'eventsEnabled' AND value = 'true' THEN 1 ELSE 0 END) AS events_enabled
  FROM realm_attribute
  WHERE name = 'eventsEnabled'
  GROUP BY realm_id
)
SELECT
  rc.realm_name,
  rc.client_id,
  rc.enabled,
  rc.public_client,
  rc.protocol,
  COALESCE(asess.active_sessions, 0)     AS active_sessions,
  COALESCE(osess.offline_sessions, 0)   AS offline_sessions,
  COALESCE(ue.user_events, 0)           AS user_events_total,
  CASE
    WHEN ue.last_user_event_ms IS NOT NULL
    THEN DATEADD(
           MILLISECOND,
           ue.last_user_event_ms % 1000,
           DATEADD(SECOND, ue.last_user_event_ms / 1000, CAST('1970-01-01' AS DATETIME2))
         )
    ELSE NULL
  END AS last_user_event_at,
  CASE
    WHEN COALESCE(asess.active_sessions, 0) > 0
      OR COALESCE(osess.offline_sessions, 0) > 0
      OR COALESCE(ue.user_events, 0) > 0
    THEN 'IN_USE'
    WHEN rc.client_id IN (
      'account', 'account-console', 'admin-cli', 'broker',
      'realm-management', 'security-admin-console'
    ) THEN 'SYSTEM_CLIENT'
    ELSE 'NO_ACTIVITY_DETECTED'
  END AS usage_status,
  COALESCE(ree.events_enabled, 0) AS realm_events_enabled
FROM realm_clients rc
LEFT JOIN active_sessions asess
  ON asess.realm_id = rc.realm_id AND asess.client_id = rc.client_id
LEFT JOIN offline_sessions osess
  ON osess.realm_id = rc.realm_id AND osess.client_id = rc.client_id
LEFT JOIN user_events ue
  ON ue.realm_id = rc.realm_id AND ue.client_id = rc.client_id
LEFT JOIN realm_events_enabled ree
  ON ree.realm_id = rc.realm_id
ORDER BY rc.realm_name, usage_status, rc.client_id;

PRINT '';
PRINT '=== Realms without user events enabled ===';

SELECT r.name AS realm_name
FROM realm r
LEFT JOIN realm_attribute ra
  ON ra.realm_id = r.id AND ra.name = 'eventsEnabled' AND ra.value = 'true'
WHERE ra.realm_id IS NULL
  AND r.name <> 'master'
ORDER BY r.name;
