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
  CREATE PROCEDURE IF NOT EXISTS core.get_pipeline_runs()
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('API_KEY' = reference('ORCHESTRA_API_KEY'))
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_pipeline_runs';

  -- Procedure to get task runs from Orchestra API
  CREATE PROCEDURE IF NOT EXISTS core.get_task_runs()
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('API_KEY' = reference('ORCHESTRA_API_KEY'))
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_task_runs';

  -- Procedure to get operations from Orchestra API
  CREATE PROCEDURE IF NOT EXISTS core.get_operations()
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('API_KEY' = reference('ORCHESTRA_API_KEY'))
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_operations';

  -- Grant permissions to all procedures
  GRANT USAGE ON PROCEDURE core.get_pipeline_runs(INT) TO APPLICATION ROLE app_public;
  GRANT USAGE ON PROCEDURE core.get_task_runs(INT) TO APPLICATION ROLE app_public;
  GRANT USAGE ON PROCEDURE core.get_operations() TO APPLICATION ROLE app_public;

  RETURN 'SUCCESS';
END;	
$$;

GRANT USAGE ON PROCEDURE core.create_eai_objects() TO APPLICATION ROLE app_public;

-- 5. Create helper procedures for data loading
CREATE OR REPLACE PROCEDURE core.load_pipeline_runs_to_table()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    pipeline_data VARIANT;
    insert_count INTEGER;
BEGIN
    -- Get pipeline runs data
    CALL core.get_pipeline_runs() INTO :pipeline_data;
    
    -- Insert data into target table
    INSERT INTO public.pipeline_runs
    SELECT 
        value:id::STRING as id,
        value:pipelineId::STRING as pipeline_id,
        value:pipelineName::STRING as pipeline_name,
        value:accountId::STRING as account_id,
        value:envId::STRING as env_id,
        value:envName::STRING as env_name,
        value:runStatus::STRING as run_status,
        value:message::STRING as message,
        value:createdAt::TIMESTAMP_NTZ as created_at,
        value:updatedAt::TIMESTAMP_NTZ as updated_at,
        value:completedAt::TIMESTAMP_NTZ as completed_at,
        value:startedAt::TIMESTAMP_NTZ as started_at,
        value:branch::STRING as branch,
        value:commit::STRING as commit,
        value:pipelineVersionNumber::NUMBER as pipeline_version_number,
        CURRENT_TIMESTAMP() as loaded_at
    FROM TABLE(FLATTEN(input => :pipeline_data:results));
    
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :pipeline_data:results));
    
    RETURN 'Successfully loaded ' || :insert_count || ' pipeline runs';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_pipeline_runs_to_table() TO APPLICATION ROLE app_public;

-- Load task runs procedure
CREATE OR REPLACE PROCEDURE core.load_task_runs_to_table()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    task_data VARIANT;
    insert_count INTEGER;
BEGIN
    -- Get task runs data
    CALL core.get_task_runs() INTO :task_data;
    
    -- Insert data into target table
    INSERT INTO public.task_runs
    SELECT 
        value:id::STRING as id,
        value:pipelineRunId::STRING as pipeline_run_id,
        value:taskName::STRING as task_name,
        value:taskId::STRING as task_id,
        value:accountId::STRING as account_id,
        value:pipelineId::STRING as pipeline_id,
        value:integration::STRING as integration,
        value:integrationJob::STRING as integration_job,
        value:status::STRING as status,
        value:message::STRING as message,
        value:externalStatus::STRING as external_status,
        value:externalMessage::STRING as external_message,
        value:platformLink::STRING as platform_link,
        value:taskParameters as task_parameters,
        value:runParameters as run_parameters,
        value:connectionId::STRING as connection_id,
        value:numberOfAttempts::NUMBER as number_of_attempts,
        value:createdAt::TIMESTAMP_NTZ as created_at,
        value:updatedAt::TIMESTAMP_NTZ as updated_at,
        value:completedAt::TIMESTAMP_NTZ as completed_at,
        value:startedAt::TIMESTAMP_NTZ as started_at,
        CURRENT_TIMESTAMP() as loaded_at
    FROM TABLE(FLATTEN(input => :task_data:task_runs));
    
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :task_data:task_runs));
    
    RETURN 'Successfully loaded ' || :insert_count || ' task runs';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_task_runs_to_table() TO APPLICATION ROLE app_public;

-- Load operations procedure
CREATE OR REPLACE PROCEDURE core.load_operations_to_table()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    operation_data VARIANT;
    insert_count INTEGER;
BEGIN
    -- Get operations data
    CALL core.get_operations() INTO :operation_data;
    
    -- Insert data into target table
    INSERT INTO public.operations
    SELECT 
        value:id::STRING as id,
        value:accountId::STRING as account_id,
        value:pipelineRunId::STRING as pipeline_run_id,
        value:taskRunId::STRING as task_run_id,
        value:insertedAt::TIMESTAMP_NTZ as inserted_at,
        value:message::STRING as message,
        value:operationName::STRING as operation_name,
        value:operationStatus::STRING as operation_status,
        value:operationType::STRING as operation_type,
        value:externalStatus::STRING as external_status,
        value:externalDetail::STRING as external_detail,
        value:externalId::STRING as external_id,
        value:integration::STRING as integration,
        value:integrationJob::STRING as integration_job,
        value:startedAt::TIMESTAMP_NTZ as started_at,
        value:completedAt::TIMESTAMP_NTZ as completed_at,
        value:dependencies as dependencies,
        value:operationDuration::FLOAT as operation_duration,
        value:rowsAffected::NUMBER as rows_affected,
        CURRENT_TIMESTAMP() as loaded_at
    FROM TABLE(FLATTEN(input => :operation_data:operations));
    
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :operation_data:operations));
    
    RETURN 'Successfully loaded ' || :insert_count || ' operations';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_operations_to_table() TO APPLICATION ROLE app_public;

-- 6. Create tables for storing Orchestra data
CREATE TABLE IF NOT EXISTS public.pipeline_runs (
    id STRING,
    pipeline_id STRING,
    pipeline_name STRING,
    account_id STRING,
    env_id STRING,
    env_name STRING,
    run_status STRING,
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
