-- Confluent Oracle Oracle CDC connector readiness script (version 1.0)
--
-- This script validates that all database pre-requisites for the Oracle CDC connector as documented in the 'Database Prerequisites' section of the documentation are met. 
-- 
-- This script does not make any modifications to the database. 
--
-- Parameters
-- 1 - Connector database user (default: C##MYUSER)
-- 2 - Pluggable database (PDB) name in case of multi-tenant database (default: '')


SET SERVEROUTPUT ON;
SET VERIFY OFF;
SET LINESIZE 200

DECLARE
    -- Types
    TYPE varchar2_tt IS TABLE OF VARCHAR2(128);

    -- Constants
    k_db_version number := DBMS_DB_VERSION.VERSION;
    
    k_new_line varchar(10) := CHR(13) || CHR(10);

    -- Global variables
    g_connector_user varchar2(128) := NVL('&1', 'C##MYUSER');

    g_pdb_name varchar2(128) := NVL('&2', '');

    g_is_multitenant boolean;

    g_is_db_vault_enabled boolean;

    g_is_rds boolean;

    g_required_system_privs varchar2_tt := varchar2_tt(
        'CREATE SESSION'
    );

    g_required_sel_obj_privs varchar2_tt := varchar2_tt(
        'V_$LOGMNR_CONTENTS', 'V_$DATABASE', 'V_$THREAD', 'V_$PARAMETER', 'V_$NLS_PARAMETERS', 'V_$NLS_PARAMETERS',
        'V_$TIMEZONE_NAMES', 'ALL_INDEXES', 'ALL_OBJECTS', 'ALL_USERS', 'ALL_CATALOG',
        'ALL_CONSTRAINTS', 'ALL_CONS_COLUMNS', 'ALL_TAB_COLS', 'ALL_IND_COLUMNS',
        'ALL_ENCRYPTED_COLUMNS', 'ALL_LOG_GROUPS', 'ALL_TAB_PARTITIONS'
    );
    
    g_required_exec_obj_privs varchar2_tt := varchar2_tt(
        'DBMS_LOGMNR'
    );
    
    -- Exceptions
    insufficient_user_role EXCEPTION;
    PRAGMA exception_init(insufficient_user_role, -20001);


-- ### Define all functions and procedures ###


-- Logs exception
PROCEDURE log_exception(p_msg IN VARCHAR2, p_errcode IN NUMBER, p_errmsg IN VARCHAR2)
IS
BEGIN
    dbms_output.put_line('ERROR: ' || p_msg);
    dbms_output.put_line('Error code: ' || p_errcode || ', Message: ' || p_errmsg);
END;


-- Checks if current user has enough privilege to run the script
PROCEDURE check_dba_role
IS
    l_result INTEGER;
BEGIN
    SELECT 1
    INTO l_result
    FROM dual
    WHERE USER IN
    (
        SELECT GRANTEE
        FROM DBA_ROLE_PRIVS
        WHERE EXISTS
        (
            SELECT *
            FROM DBA_USERS u
            WHERE GRANTEE = u.username
        )
        START WITH GRANTED_ROLE = 'DBA'
        CONNECT BY PRIOR GRANTEE = GRANTED_ROLE
    );
EXCEPTION
    WHEN no_data_found THEN
        RAISE_APPLICATION_ERROR(-20001, 'ERROR: Current user does not have DBA role. Please execute the script using a user having DBA role.');
    WHEN others THEN
        log_exception('Failed to check if current user has DBA role.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
        raise;
END;


--  Checks if current environment is AWS RDS
FUNCTION is_db_rds RETURN BOOLEAN 
IS
    l_count number;
BEGIN
    SELECT COUNT(*)
    INTO l_count
    FROM DBA_PROCEDURES
    WHERE OBJECT_TYPE = 'PACKAGE' AND OBJECT_NAME = 'RDSADMIN';
    
    IF l_count = 0 THEN
        return FALSE;
    ELSE
        dbms_output.put_line('Detected AWS RDS environment');
        return TRUE;
    END IF;
EXCEPTION
    WHEN others THEN
        log_exception('Failed to check if environment is AWS RDS.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
        raise;
END;


--  Checks if DB architecture is Multitenant or not
FUNCTION is_db_multitenant RETURN BOOLEAN
IS
    l_is_cdb varchar(3);
BEGIN
    IF k_db_version <= 11 THEN
        dbms_output.put_line('Detected non-multitenant database architecture.');
        return FALSE;
    END IF;

    -- Using execute immediate otherwise it will fail to compile for older oracle versions
    EXECUTE IMMEDIATE 'SELECT CDB FROM V$DATABASE' INTO l_is_cdb;

    IF l_is_cdb = 'YES' THEN
        dbms_output.put_line('Detected multitenant database architecture.');
        return TRUE;
    ELSE
        dbms_output.put_line('Detected non-multitenant database architecture.');
        return FALSE;
    END IF;
EXCEPTION
    when others THEN
        log_exception('Failed to fetch database architecture type.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
        raise;
END;


-- Checks if database vault is enabled
FUNCTION is_db_vault_enabled RETURN BOOLEAN
IS
    l_value V$OPTION.VALUE%TYPE;
BEGIN
    SELECT VALUE
    INTO l_value
    FROM V$OPTION
    WHERE PARAMETER = 'Oracle Database Vault';
    
    IF l_value = 'TRUE' THEN
        return TRUE;
    ELSE
        return FALSE;
    END IF;
EXCEPTION
    when others THEN
        log_exception('Failed to check if database vault is enabled.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
        raise;
END;


-- Checks if user has all the required system privileges in place
PROCEDURE validate_sys_privs
IS
    l_privs_found varchar2_tt;
    l_missing_privs_str varchar2(1000) := '';
    l_privs_docs_url varchar2(1000) := 'https://docs.confluent.io/cloud/current/connectors/cc-oracle-cdc-source/oracle-cdc-setup-includes/prereqs-validation.html#connect-oracle-cdc-source-prereqs-user-privileges';
BEGIN
    dbms_output.put_line(k_new_line || 'Validating required system priviliges:');
    SELECT DISTINCT(PRIVILEGE)
    BULK COLLECT INTO l_privs_found
    FROM DBA_SYS_PRIVS
    WHERE GRANTEE = g_connector_user OR GRANTEE IN
    (
        SELECT GRANTED_ROLE
        FROM DBA_ROLE_PRIVS
        CONNECT BY PRIOR GRANTED_ROLE = GRANTEE 
        START WITH GRANTEE = g_connector_user
    );

    FOR i IN 1..g_required_system_privs.count LOOP
        IF g_required_system_privs(i) NOT MEMBER OF l_privs_found THEN
            IF l_missing_privs_str IS NOT NULL THEN
                l_missing_privs_str := l_missing_privs_str || ', ';
            END IF;
            l_missing_privs_str := l_missing_privs_str || g_required_system_privs(i);
        END IF;
    END LOOP;
    
    IF l_missing_privs_str is null THEN
        dbms_output.put_line('SUCCESS: Connector user has the required system privileges.');
    ELSE
        dbms_output.put_line('FAILED: Connector user ' || g_connector_user || ' is missing some of the required system privileges - ' || l_missing_privs_str);
        dbms_output.put_line('Please refer to the documentation for steps to grant this access - ' || l_privs_docs_url);
    END IF;
EXCEPTION
    WHEN others THEN
        log_exception('Failed to validate required system privileges for the user.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
END;


-- Checks if user has supplied privilege on the provided objects
PROCEDURE validate_obj_privs(p_priv IN VARCHAR2, p_required_objs IN varchar2_tt)
IS
    l_privs_found varchar2_tt;
    l_missing_privs_str varchar2(1000) := '';
    l_privs_docs_url varchar2(1000) := 'https://docs.confluent.io/cloud/current/connectors/cc-oracle-cdc-source/oracle-cdc-setup-includes/prereqs-validation.html#connect-oracle-cdc-source-prereqs-user-privileges';
BEGIN
    dbms_output.put_line(k_new_line || 'Validating required ' || p_priv || ' privileges to objects:');
    IF g_is_multitenant AND g_pdb_name IS NOT NULL THEN
        
        -- Need to use EXECUTE IMMEDIATE because COMMON column does not exist on non multitenant architectures and it will fail to compile
        EXECUTE IMMEDIATE '
        SELECT DISTINCT(TABLE_NAME)
        FROM DBA_TAB_PRIVS
        WHERE PRIVILEGE = ''' || p_priv || ''' AND COMMON = ''YES'' AND
        (
            GRANTEE = ''PUBLIC'' OR GRANTEE = ''' || g_connector_user || ''' OR GRANTEE IN 
            (
                SELECT GRANTED_ROLE 
                FROM DBA_ROLE_PRIVS 
                CONNECT BY PRIOR GRANTED_ROLE = GRANTEE 
                START WITH GRANTEE = ''' || g_connector_user || '''
            )
        )'
        BULK COLLECT INTO l_privs_found;
    ELSE
        SELECT DISTINCT(TABLE_NAME)
        BULK COLLECT INTO l_privs_found
        FROM DBA_TAB_PRIVS
        WHERE PRIVILEGE = p_priv AND
        (
            GRANTEE = 'PUBLIC' OR GRANTEE = g_connector_user OR GRANTEE IN 
            (
                SELECT GRANTED_ROLE
                FROM DBA_ROLE_PRIVS
                CONNECT BY PRIOR GRANTED_ROLE = GRANTEE
                START WITH GRANTEE = g_connector_user
            )    
        );
    END IF;
    
    FOR i IN 1..p_required_objs.count LOOP
        IF p_required_objs(i) NOT MEMBER OF l_privs_found THEN
            IF l_missing_privs_str IS NOT NULL THEN
                l_missing_privs_str := l_missing_privs_str || ', ';
            END IF;
            l_missing_privs_str := l_missing_privs_str || p_required_objs(i);
        END IF;
    END LOOP;
    
    IF l_missing_privs_str IS NULL THEN
        dbms_output.put_line('SUCCESS: Connector user has the required ' || p_priv || ' object privileges.');
    ELSE
        dbms_output.put_line('FAILED: Connector user ' || g_connector_user || ' is missing some of the required ' || p_priv || ' object privileges - ' || l_missing_privs_str);
        dbms_output.put_line('Please refer to the documentation for steps to grant this access - ' || l_privs_docs_url);
    END IF;
EXCEPTION
    WHEN others THEN
        log_exception('Failed to validate required ' || p_priv || ' object privileges for the user', SQLCODE, SUBSTR(SQLERRM, 1, 128));
END;


-- Checks if log mode is set to ARCHIVE
PROCEDURE validate_log_mode
IS
    l_db_log_mode varchar2(128);
    l_log_mode_docs_url varchar2(1000) := 'https://docs.confluent.io/cloud/current/connectors/cc-oracle-cdc-source/oracle-cdc-setup-includes/prereqs-validation.html#connect-oracle-cdc-source-prereqs-archivelog-mode';
BEGIN
    dbms_output.put_line(k_new_line || 'Validating database log mode:');
    SELECT LOG_MODE
    INTO l_db_log_mode
    FROM V$DATABASE;
    
    IF l_db_log_mode = 'ARCHIVELOG' THEN
        dbms_output.put_line('SUCCESS: Database is set to ARCHIVELOG mode as expected.');
    ELSE
        dbms_output.put_line('FAILED: Database must be set to ARCHIVELOG mode. Current mode: ' || l_db_log_mode);
        dbms_output.put_line('Please refer to the documentation for the procedure to set the database to ARCHIVELOG mode - ' || l_log_mode_docs_url);
    END IF;
EXCEPTION
    WHEN others THEN
        log_exception('Failed to validate database log mode', SQLCODE, SUBSTR(SQLERRM, 1, 128));
END;


-- Checks if supplemental logs is enabled or not
PROCEDURE validate_supplemental_logging
IS
    l_count number;
    l_supp_log_min V$DATABASE.SUPPLEMENTAL_LOG_DATA_MIN%TYPE;
    l_supp_log_all V$DATABASE.SUPPLEMENTAL_LOG_DATA_ALL%TYPE;
    l_supp_docs_url varchar2(1000) := 'https://docs.confluent.io/cloud/current/connectors/cc-oracle-cdc-source/oracle-cdc-setup-includes/prereqs-validation.html#connect-oracle-cdc-source-prereqs-enable-supplemental-logging';
    l_dba_supp_logging_docs_url varchar2(1000) := 'https://docs.confluent.io/kafka-connectors/oracle-cdc/current/prereqs-validation.html#multitenant-database-pdb';
BEGIN
    dbms_output.put_line(k_new_line || 'Validating supplemental logging:');
    SELECT SUPPLEMENTAL_LOG_DATA_MIN, SUPPLEMENTAL_LOG_DATA_ALL
    INTO l_supp_log_min, l_supp_log_all
    FROM V$DATABASE;

    IF l_supp_log_all = 'YES' THEN
        dbms_output.put_line('WARN: ALL column supplemental logging is enabled at the database level. Confluent recommends enabling minimal supplemental logging at the database level and ALL column supplemental logging for the specific tables that require change data capture.');
        dbms_output.put_line('Please refer to the documentation for the procedure to enable supplemental logging - ' || l_supp_docs_url);
    ELSIF l_supp_log_min = 'NO' THEN
        dbms_output.put_line('FAILED: Minimal supplemental logging is not enabled and is required for the connector to function. Confluent recommends enabling minimal supplemental logging at the database level and ALL column supplemental logging for the specific tables that require change data capture.');
        dbms_output.put_line('Please refer to the documentation for the procedure to enable supplemental logging - ' || l_supp_docs_url);
    ELSIF k_db_version >= 19 AND g_is_multitenant AND g_pdb_name IS NOT NULL THEN
        EXECUTE IMMEDIATE '
        SELECT COUNT(*)
        FROM DBA_TAB_PRIVS
        WHERE TABLE_NAME = ''DBA_SUPPLEMENTAL_LOGGING'' AND PRIVILEGE = ''SELECT'' AND COMMON = ''YES'' AND
        (
            GRANTEE = ''PUBLIC'' OR GRANTEE = ''' || g_connector_user || ''' OR GRANTEE IN 
            (
                SELECT GRANTED_ROLE 
                FROM DBA_ROLE_PRIVS 
                CONNECT BY PRIOR GRANTED_ROLE = GRANTEE 
                START WITH GRANTEE = ''' || g_connector_user || '''
            )
        )'
        INTO l_count;

        IF l_count > 0 THEN
            dbms_output.put_line('WARN: Please ensure that ALL column supplemental logging is enabled for the specific tables that require change data capture.');
            dbms_output.put_line('Please refer to the documentation for the procedure to enable supplemental logging - ' || l_supp_docs_url);
        ELSE
            dbms_output.put_line('FAILED: Connector user does not have required access to DBA_SUPPLEMENTAL_LOGGING. Please grant access to this object to the connector user. This is only required when ALL column supplemental logging is enabled for specific tables.');
            dbms_output.put_line('Please refer to the documentation for the steps to grant access to this object - ' || l_dba_supp_logging_docs_url);
        END IF;
    ELSE
        dbms_output.put_line('WARN: Please ensure that ALL column supplemental logging is enabled for the specific tables that require change data capture.');
        dbms_output.put_line('Please refer to the documentation for the procedure to enable supplemental logging - ' || l_supp_docs_url);
    END IF;
EXCEPTION
    WHEN others THEN
        log_exception('Failed to validate supplemental logging', SQLCODE, SUBSTR(SQLERRM, 1, 128));
END;


-- Checks if user has flashback access
PROCEDURE validate_flashback
IS
    l_count number;
    l_flashback_docs_url varchar2(1000) := 'https://docs.confluent.io/cloud/current/connectors/cc-oracle-cdc-source/oracle-cdc-setup-includes/prereqs-validation.html#connect-oracle-cdc-source-prereqs-grant-user-flashback';
BEGIN
    dbms_output.put_line(k_new_line || 'Validating flashback access:');
    SELECT COUNT(*)
    INTO l_count
    FROM DBA_SYS_PRIVS
    WHERE PRIVILEGE = 'FLASHBACK ANY TABLE' AND
    (
        GRANTEE = g_connector_user OR GRANTEE IN
        (
            SELECT GRANTED_ROLE
            FROM DBA_ROLE_PRIVS
            CONNECT BY PRIOR GRANTED_ROLE = GRANTEE 
            START WITH GRANTEE = g_connector_user
        )
    );

    IF l_count > 0 THEN
        dbms_output.put_line('SUCCESS: Connector user has the FLASHBACK ANY TABLE system privilege.');
    ELSE
        dbms_output.put_line('WARN: Connector user ' || g_connector_user || ' does not have FLASHBACK ANY TABLE system privilege. This user must have either the FLASHBACK ANY TABLE system privilege or have FLASHBACK object privilege on the specific tables to snapshot.');
        dbms_output.put_line('Please refer to the documentation for the steps on how to grant this access - ' || l_flashback_docs_url);
    END IF;

EXCEPTION
    WHEN others THEN
        log_exception('Failed to validate flashback access.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
END;


-- Checks the archive log retention. Can only get it for RDS at the moment.
PROCEDURE validate_archive_log_retention
IS
    l_retention_hours NUMBER;
    l_rds_docs_url varchar2(1000) := 'https://docs.confluent.io/kafka-connectors/oracle-cdc/current/prereqs-validation.html#amazon-rds-oracle-19c-12c-instance';
BEGIN
    dbms_output.put_line(k_new_line || 'Validating archive log retention period:');

    IF g_is_rds THEN
        -- Using execute immediate otherwise it will fail to compile for non RDS DBs
        EXECUTE IMMEDIATE 'SELECT value FROM rdsadmin.rds_configuration WHERE name =''archivelog retention hours''' INTO l_retention_hours;
        
        IF l_retention_hours < 24 THEN
            dbms_output.put_line('WARN: Confluent recommends you increase your archive log retention policies to at least 24 hours.');
            dbms_output.put_line('Please refer to the documentation for steps to increase the retention period - ' || l_rds_docs_url);
        ELSE
            dbms_output.put_line('SUCCESS: Archive log retention value set as recommended value.');
        END IF;
    ELSE
        dbms_output.put_line('WARN: Can not check archive log retention time for non AWS RDS environment. Confluent recommends you increase your archive log retention policies to at least 24 hours.');
    END IF;
EXCEPTION
    WHEN others THEN
        log_exception('Failed to fetch archive log retention.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
END;


-- Checks if redo log switch frequency is more than recommended value.
PROCEDURE validate_redo_log_switches
IS
    l_crossing_threshold_count number;
    k_log_switch_threshold number := 4;
BEGIN
    dbms_output.put_line(k_new_line || 'Validating redo log switch frequency:');
    
    SELECT COUNT(*)
    INTO l_crossing_threshold_count
    FROM
    (
        SELECT count(1)
        FROM V$LOG_HISTORY
        WHERE FIRST_TIME > SYSDATE - 30
        GROUP BY thread#, to_char(first_time,'YYYY-MON-DD HH24')
        HAVING COUNT(1) > k_log_switch_threshold
    );
        
    IF l_crossing_threshold_count > 0 THEN
        dbms_output.put_line('WARN: Confluent recommends to size your online redo log files to ensure that there is no more than ' || k_log_switch_threshold || ' log switches per hour during peak DML activity. Detected ' || l_crossing_threshold_count || ' hourly redo log switches greater than recommended value in the past 30 days.');
    ELSE
        dbms_output.put_line('SUCCESS: Redo log switch frequency within recommended value.');
    END IF;
EXCEPTION
    WHEN others THEN
        log_exception('Could not check redo log switch frequency.', SQLCODE, SUBSTR(SQLERRM, 1, 128));
END;


-- Populates required system privileges based on database version and architecture
PROCEDURE init_required_sys_privs 
IS
BEGIN
    IF k_db_version = 11 THEN
        g_required_system_privs := g_required_system_privs MULTISET UNION varchar2_tt('SELECT ANY TRANSACTION');
    ELSE
        g_required_system_privs := g_required_system_privs MULTISET UNION varchar2_tt('LOGMINING');
    END IF;
    
    IF g_is_multitenant AND g_pdb_name IS NOT NULL THEN
        g_required_system_privs := g_required_system_privs MULTISET UNION varchar2_tt('SET CONTAINER');
    END IF;
END;


-- Populates required select object privileges based on database version and architecture
PROCEDURE init_required_sel_obj_privs
IS
BEGIN
    IF g_is_rds THEN
        g_required_sel_obj_privs := g_required_sel_obj_privs MULTISET UNION varchar2_tt('V_$LOGMNR_LOGS', 'V_$TRANSACTION', 'ALL_VIEWS');
    END IF;

    IF g_pdb_name IS NOT NULL THEN
        g_required_sel_obj_privs := g_required_sel_obj_privs MULTISET UNION varchar2_tt('DBA_PDBS', 'CDB_TABLES', 'CDB_TAB_PARTITIONS');
    ELSE
        g_required_sel_obj_privs := g_required_sel_obj_privs MULTISET UNION varchar2_tt('ALL_TABLES');
    END IF;
  
    IF k_db_version >= 19 THEN
        g_required_sel_obj_privs := g_required_sel_obj_privs MULTISET UNION varchar2_tt('V_$INSTANCE');
    END IF;
  
    IF k_db_version >= 19 OR g_is_rds THEN
        g_required_sel_obj_privs := g_required_sel_obj_privs MULTISET UNION varchar2_tt('V_$ARCHIVED_LOG', 'V_$LOG', 'V_$LOGFILE', 'V_$INSTANCE');
    END IF;
END;


-- Populates required execute object privileges based on database version and architecture
PROCEDURE init_required_exec_obj_privs
IS
BEGIN
    IF g_is_db_vault_enabled AND k_db_version >= 12 AND g_pdb_name IS NULL AND NOT g_is_rds THEN
        g_required_exec_obj_privs := g_required_exec_obj_privs MULTISET UNION varchar2_tt('DBMS_LOGMNR_D');
    END IF;
END;


-- MAIN SCRIPT
BEGIN
    dbms_output.put_line('Running prerequistes check for Confluent Oracle CDC connector on Oracle Database ' || k_db_version || ' for the user ' || g_connector_user);
    
    check_dba_role();

    g_is_rds := is_db_rds();

    g_is_multitenant := is_db_multitenant();
    
    g_is_db_vault_enabled := is_db_vault_enabled();

    -- PDB is only relevant in multitenant, non RDS environments.
    IF g_pdb_name IS NOT NULL THEN
        IF g_is_multitenant AND NOT g_is_rds THEN
            dbms_output.put_line('PDB supplied: ' || g_pdb_name);
        ELSE
            g_pdb_name := '';
        END IF;
    END IF;

    init_required_sys_privs();
    init_required_sel_obj_privs();
    init_required_exec_obj_privs();

    validate_sys_privs();
    validate_obj_privs('SELECT', g_required_sel_obj_privs);
    validate_obj_privs('EXECUTE', g_required_exec_obj_privs);
    validate_log_mode();
    validate_supplemental_logging();
    validate_flashback();
    validate_archive_log_retention();
    validate_redo_log_switches();

    dbms_output.put_line(k_new_line || 'Finished script execution.');
EXCEPTION
    WHEN insufficient_user_role THEN
        dbms_output.put_line(SQLERRM);
    WHEN others THEN
        dbms_output.put_line('ERROR: Unexpected error occurred. Stopping script execution...');
END;
