-- 1. Create application roles
CREATE APPLICATION ROLE IF NOT EXISTS app_public;

-- 2. Create a versioned schema to hold those UDFs/Stored Procedures
CREATE OR ALTER VERSIONED SCHEMA core;
CREATE SCHEMA IF NOT EXISTS public;
GRANT USAGE ON SCHEMA core TO APPLICATION ROLE app_public;
GRANT USAGE ON SCHEMA public TO APPLICATION ROLE app_public;

-- 3. Create callbacks called in the manifest.yml
CREATE OR REPLACE PROCEDURE core.register_single_callback(ref_name STRING, operation STRING, ref_or_alias STRING)
RETURNS STRING
LANGUAGE SQL
AS 
$$
  BEGIN
    CASE (operation)
      WHEN 'ADD' THEN
        SELECT SYSTEM$SET_REFERENCE(:ref_name, :ref_or_alias);
      WHEN 'REMOVE' THEN
        SELECT SYSTEM$REMOVE_REFERENCE(:ref_name);
      WHEN 'CLEAR' THEN
        SELECT SYSTEM$REMOVE_REFERENCE(:ref_name);
    ELSE
      RETURN 'unknown operation: ' || operation;
    END CASE;
  END;
$$;

GRANT USAGE ON PROCEDURE core.register_single_callback(STRING, STRING, STRING) TO APPLICATION ROLE app_public;

-- Configuration callback for the `EXTERNAL_ACCESS_REFERENCE` defined in the manifest.yml
-- The procedure returns a json format object containing information about the EAI to be created
-- This allows the app to access the Orchestra API
CREATE OR REPLACE PROCEDURE core.get_configuration(ref_name STRING)
RETURNS STRING
LANGUAGE SQL
AS 
$$
BEGIN
  CASE (UPPER(ref_name))
      WHEN 'EXTERNAL_ACCESS_REFERENCE' THEN
          RETURN OBJECT_CONSTRUCT(
              'type', 'CONFIGURATION',
              'payload', OBJECT_CONSTRUCT(
                  'host_ports', ARRAY_CONSTRUCT('app.getorchestra.io'),
                  'allowed_secrets', 'LIST',
                  'secret_references', ARRAY_CONSTRUCT('ORCHESTRA_API_KEY')
              )
          )::STRING;
      WHEN 'ORCHESTRA_API_KEY' THEN
        RETURN OBJECT_CONSTRUCT(
            'type', 'CONFIGURATION',
            'payload', OBJECT_CONSTRUCT(
                'type', 'GENERIC_STRING'
            )
        )::STRING;
      ELSE
          RETURN '';
  END CASE;
END;	
$$;

GRANT USAGE ON PROCEDURE core.get_configuration(STRING) TO APPLICATION ROLE app_public;

-- 4. Create stored procedures using the external access reference from the manifest.yml
-- The Stored Procedures need to be created in runtime because EAI reference needs to be set
-- after installing the application.
CREATE OR REPLACE PROCEDURE core.create_eai_objects()
RETURNS STRING
LANGUAGE SQL
AS 
$$
BEGIN
  -- Procedure to get pipeline runs from Orchestra API
  CREATE PROCEDURE IF NOT EXISTS core.get_pipeline_runs(api_key STRING, limit_param INT DEFAULT 100)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('ORCHESTRA_API_KEY' = api_key)
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_pipeline_runs';

  -- Procedure to get task runs from Orchestra API
  CREATE PROCEDURE IF NOT EXISTS core.get_task_runs(api_key STRING, limit_param INT DEFAULT 100)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('ORCHESTRA_API_KEY' = api_key)
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_task_runs';

  -- Procedure to get operations from Orchestra API
  CREATE PROCEDURE IF NOT EXISTS core.get_operations(api_key STRING)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('ORCHESTRA_API_KEY' = api_key)
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_operations';

  -- Grant permissions to all procedures
  GRANT USAGE ON PROCEDURE core.get_pipeline_runs(STRING, INT) TO APPLICATION ROLE app_public;
  GRANT USAGE ON PROCEDURE core.get_task_runs(STRING, INT) TO APPLICATION ROLE app_public;
  GRANT USAGE ON PROCEDURE core.get_operations(STRING) TO APPLICATION ROLE app_public;

  RETURN 'SUCCESS';
END;	
$$;

GRANT USAGE ON PROCEDURE core.create_eai_objects() TO APPLICATION ROLE app_public;

-- 5. Create helper procedures for data loading
CREATE OR REPLACE PROCEDURE core.load_pipeline_runs_to_table(api_key STRING, target_table STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    pipeline_data VARIANT;
    insert_count INTEGER;
    full_table_name STRING;
BEGIN
    -- Use hardcoded database and schema
    SET full_table_name = 'ORCHESTRA_DATA.public.' || :target_table;
    
    -- Get pipeline runs data
    SELECT core.get_pipeline_runs(:api_key, 1000) INTO :pipeline_data;
    
    -- Insert data into target table
    INSERT INTO IDENTIFIER(:full_table_name)
    SELECT 
        value:id::STRING as id,
        value:pipeline_id::STRING as pipeline_id,
        value:pipeline_name::STRING as pipeline_name,
        value:account_id::STRING as account_id,
        value:env_id::STRING as env_id,
        value:env_name::STRING as env_name,
        value:run_status::STRING as run_status,
        value:triggered_by as triggered_by,
        value:child_pipeline_runs as child_pipeline_runs,
        value:message::STRING as message,
        value:created_at::TIMESTAMP_NTZ as created_at,
        value:updated_at::TIMESTAMP_NTZ as updated_at,
        value:completed_at::TIMESTAMP_NTZ as completed_at,
        value:started_at::TIMESTAMP_NTZ as started_at,
        value:branch::STRING as branch,
        value:commit::STRING as commit,
        value:pipeline_version_number::NUMBER as pipeline_version_number,
        CURRENT_TIMESTAMP() as loaded_at
    FROM TABLE(FLATTEN(input => :pipeline_data:pipeline_runs));
    
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :pipeline_data:pipeline_runs));
    
    RETURN 'Successfully loaded ' || :insert_count || ' pipeline runs';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_pipeline_runs_to_table(STRING, STRING) TO APPLICATION ROLE app_public;

-- Load task runs procedure
CREATE OR REPLACE PROCEDURE core.load_task_runs_to_table(api_key STRING, target_table STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    task_data VARIANT;
    insert_count INTEGER;
    full_table_name STRING;
BEGIN
    -- Use hardcoded database and schema
    SET full_table_name = 'ORCHESTRA_DATA.public.' || :target_table;
    
    -- Get task runs data
    SELECT core.get_task_runs(:api_key, 1000) INTO :task_data;
    
    -- Insert data into target table
    INSERT INTO IDENTIFIER(:full_table_name)
    SELECT 
        value:id::STRING as id,
        value:pipeline_run_id::STRING as pipeline_run_id,
        value:task_name::STRING as task_name,
        value:task_id::STRING as task_id,
        value:account_id::STRING as account_id,
        value:pipeline_id::STRING as pipeline_id,
        value:integration::STRING as integration,
        value:integration_job::STRING as integration_job,
        value:status::STRING as status,
        value:message::STRING as message,
        value:external_status::STRING as external_status,
        value:external_message::STRING as external_message,
        value:platform_link::STRING as platform_link,
        value:task_parameters as task_parameters,
        value:run_parameters as run_parameters,
        value:connection_id::STRING as connection_id,
        value:number_of_attempts::NUMBER as number_of_attempts,
        value:created_at::TIMESTAMP_NTZ as created_at,
        value:updated_at::TIMESTAMP_NTZ as updated_at,
        value:completed_at::TIMESTAMP_NTZ as completed_at,
        value:started_at::TIMESTAMP_NTZ as started_at,
        CURRENT_TIMESTAMP() as loaded_at
    FROM TABLE(FLATTEN(input => :task_data:task_runs));
    
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :task_data:task_runs));
    
    RETURN 'Successfully loaded ' || :insert_count || ' task runs';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_task_runs_to_table(STRING, STRING) TO APPLICATION ROLE app_public;

-- Load operations procedure
CREATE OR REPLACE PROCEDURE core.load_operations_to_table(api_key STRING, target_table STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    operation_data VARIANT;
    insert_count INTEGER;
    full_table_name STRING;
BEGIN
    -- Use hardcoded database and schema
    SET full_table_name = 'ORCHESTRA_DATA.public.' || :target_table;
    
    -- Get operations data
    SELECT core.get_operations(:api_key) INTO :operation_data;
    
    -- Insert data into target table
    INSERT INTO IDENTIFIER(:full_table_name)
    SELECT 
        value:id::STRING as id,
        value:account_id::STRING as account_id,
        value:pipeline_run_id::STRING as pipeline_run_id,
        value:task_run_id::STRING as task_run_id,
        value:inserted_at::TIMESTAMP_NTZ as inserted_at,
        value:message::STRING as message,
        value:operation_name::STRING as operation_name,
        value:operation_status::STRING as operation_status,
        value:operation_type::STRING as operation_type,
        value:external_status::STRING as external_status,
        value:external_detail::STRING as external_detail,
        value:external_id::STRING as external_id,
        value:integration::STRING as integration,
        value:integration_job::STRING as integration_job,
        value:started_at::TIMESTAMP_NTZ as started_at,
        value:completed_at::TIMESTAMP_NTZ as completed_at,
        value:dependencies as dependencies,
        value:operation_duration::FLOAT as operation_duration,
        value:rows_affected::NUMBER as rows_affected,
        CURRENT_TIMESTAMP() as loaded_at
    FROM TABLE(FLATTEN(input => :operation_data:operations));
    
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :operation_data:operations));
    
    RETURN 'Successfully loaded ' || :insert_count || ' operations';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_operations_to_table(STRING, STRING) TO APPLICATION ROLE app_public;

-- 6. Create validation procedure to check database and schema existence
CREATE OR REPLACE PROCEDURE core.validate_database_schema()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    db_exists BOOLEAN;
    schema_exists BOOLEAN;
BEGIN
    -- Check if database exists
    SELECT COUNT(*) > 0 INTO :db_exists 
    FROM INFORMATION_SCHEMA.DATABASES 
    WHERE DATABASE_NAME = 'ORCHESTRA_DATA';
    
    IF (NOT :db_exists) THEN
        RETURN 'ERROR: Database ORCHESTRA_DATA does not exist. Please create it before running this app.';
    END IF;
    
    -- Check if schema exists
    SELECT COUNT(*) > 0 INTO :schema_exists 
    FROM INFORMATION_SCHEMA.SCHEMATA 
    WHERE CATALOG_NAME = 'ORCHESTRA_DATA' AND SCHEMA_NAME = 'PUBLIC';
    
    IF (NOT :schema_exists) THEN
        RETURN 'ERROR: Schema ORCHESTRA_DATA.PUBLIC does not exist. Please create it before running this app.';
    END IF;
    
    RETURN 'SUCCESS: Database and schema validation passed.';
END;
$$;

GRANT USAGE ON PROCEDURE core.validate_database_schema() TO APPLICATION ROLE app_public;

-- 7. Create tables for storing Orchestra data

-- Create the tables
CREATE TABLE IF NOT EXISTS public.pipeline_runs (
    id STRING,
    pipeline_id STRING,
    pipeline_name STRING,
    account_id STRING,
    env_id STRING,
    env_name STRING,
    run_status STRING,
    triggered_by VARIANT,
    child_pipeline_runs VARIANT,
    message STRING,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    started_at TIMESTAMP_NTZ,
    branch STRING,
    commit STRING,
    pipeline_version_number NUMBER,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS public.task_runs (
    id STRING,
    pipeline_run_id STRING,
    task_name STRING,
    task_id STRING,
    account_id STRING,
    pipeline_id STRING,
    integration STRING,
    integration_job STRING,
    status STRING,
    message STRING,
    external_status STRING,
    external_message STRING,
    platform_link STRING,
    task_parameters VARIANT,
    run_parameters VARIANT,
    connection_id STRING,
    number_of_attempts NUMBER,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    started_at TIMESTAMP_NTZ,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS public.operations (
    id STRING,
    account_id STRING,
    pipeline_run_id STRING,
    task_run_id STRING,
    inserted_at TIMESTAMP_NTZ,
    message STRING,
    operation_name STRING,
    operation_status STRING,
    operation_type STRING,
    external_status STRING,
    external_detail STRING,
    external_id STRING,
    integration STRING,
    integration_job STRING,
    started_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    dependencies VARIANT,
    operation_duration FLOAT,
    rows_affected NUMBER,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Grant permissions on tables
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.pipeline_runs TO APPLICATION ROLE app_public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.task_runs TO APPLICATION ROLE app_public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.operations TO APPLICATION ROLE app_public;