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
  CREATE PROCEDURE IF NOT EXISTS core.get_pipeline_runs(page INT DEFAULT 1, per_page INT DEFAULT 100)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('API_KEY' = reference('ORCHESTRA_API_KEY'))
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_pipeline_runs';

  -- Procedure to get task runs from Orchestra API
  CREATE PROCEDURE IF NOT EXISTS core.get_task_runs(page INT DEFAULT 1, per_page INT DEFAULT 100)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('API_KEY' = reference('ORCHESTRA_API_KEY'))
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_task_runs';

  -- Procedure to get operations from Orchestra API
  CREATE PROCEDURE IF NOT EXISTS core.get_operations(page INT DEFAULT 1, per_page INT DEFAULT 100)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = 3.12
  IMPORTS=('/module-api/orchestra.py')
  EXTERNAL_ACCESS_INTEGRATIONS = (reference('external_access_reference'))
  SECRETS = ('API_KEY' = reference('ORCHESTRA_API_KEY'))
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'orchestra.get_operations';

  -- Grant permissions to all procedures
  GRANT USAGE ON PROCEDURE core.get_pipeline_runs(INT, INT) TO APPLICATION ROLE app_public;
  GRANT USAGE ON PROCEDURE core.get_task_runs(INT, INT) TO APPLICATION ROLE app_public;
  GRANT USAGE ON PROCEDURE core.get_operations(INT, INT) TO APPLICATION ROLE app_public;

  RETURN 'SUCCESS';
END;	
$$;

GRANT USAGE ON PROCEDURE core.create_eai_objects() TO APPLICATION ROLE app_public;

-- 5. Create helper procedures for data loading
CREATE OR REPLACE PROCEDURE core.load_pipeline_runs()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    pipeline_data VARIANT;
    insert_count INTEGER;
    update_count INTEGER;
BEGIN
    -- Get pipeline runs data
    CALL core.get_pipeline_runs() INTO :pipeline_data;
    
    -- Merge data into target table (insert new, update existing)
    MERGE INTO public.pipeline_runs AS target
    USING (
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
        FROM TABLE(FLATTEN(input => :pipeline_data:results))
    ) AS source
    ON target.id = source.id
    WHEN MATCHED THEN
        UPDATE SET
            pipeline_id = source.pipeline_id,
            pipeline_name = source.pipeline_name,
            account_id = source.account_id,
            env_id = source.env_id,
            env_name = source.env_name,
            run_status = source.run_status,
            message = source.message,
            created_at = source.created_at,
            updated_at = source.updated_at,
            completed_at = source.completed_at,
            started_at = source.started_at,
            branch = source.branch,
            commit = source.commit,
            pipeline_version_number = source.pipeline_version_number,
            loaded_at = source.loaded_at
    WHEN NOT MATCHED THEN
        INSERT (
            id, pipeline_id, pipeline_name, account_id, env_id, env_name,
            run_status, message, created_at, updated_at, completed_at, started_at,
            branch, commit, pipeline_version_number, loaded_at
        )
        VALUES (
            source.id, source.pipeline_id, source.pipeline_name, source.account_id,
            source.env_id, source.env_name, source.run_status, source.message,
            source.created_at, source.updated_at, source.completed_at, source.started_at,
            source.branch, source.commit, source.pipeline_version_number, source.loaded_at
        );
    
    -- Get counts for reporting
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :pipeline_data:results));
    
    RETURN 'Successfully processed ' || :insert_count || ' pipeline runs (inserted new or updated existing)';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_pipeline_runs() TO APPLICATION ROLE app_public;

-- Load task runs procedure
CREATE OR REPLACE PROCEDURE core.load_task_runs()
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
    
    -- Merge data into target table (insert new, update existing)
    MERGE INTO public.task_runs AS target
    USING (
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
        FROM TABLE(FLATTEN(input => :task_data:results))
    ) AS source
    ON target.id = source.id
    WHEN MATCHED THEN
        UPDATE SET
            pipeline_run_id = source.pipeline_run_id,
            task_name = source.task_name,
            task_id = source.task_id,
            account_id = source.account_id,
            pipeline_id = source.pipeline_id,
            integration = source.integration,
            integration_job = source.integration_job,
            status = source.status,
            message = source.message,
            external_status = source.external_status,
            external_message = source.external_message,
            platform_link = source.platform_link,
            task_parameters = source.task_parameters,
            run_parameters = source.run_parameters,
            connection_id = source.connection_id,
            number_of_attempts = source.number_of_attempts,
            created_at = source.created_at,
            updated_at = source.updated_at,
            completed_at = source.completed_at,
            started_at = source.started_at,
            loaded_at = source.loaded_at
    WHEN NOT MATCHED THEN
        INSERT (
            id, pipeline_run_id, task_name, task_id, account_id, pipeline_id,
            integration, integration_job, status, message, external_status,
            external_message, platform_link, task_parameters, run_parameters,
            connection_id, number_of_attempts, created_at, updated_at,
            completed_at, started_at, loaded_at
        )
        VALUES (
            source.id, source.pipeline_run_id, source.task_name, source.task_id,
            source.account_id, source.pipeline_id, source.integration,
            source.integration_job, source.status, source.message,
            source.external_status, source.external_message, source.platform_link,
            source.task_parameters, source.run_parameters, source.connection_id,
            source.number_of_attempts, source.created_at, source.updated_at,
            source.completed_at, source.started_at, source.loaded_at
        );
    
    -- Get counts for reporting
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :task_data:results));
    
    RETURN 'Successfully processed ' || :insert_count || ' task runs (inserted new or updated existing)';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_task_runs() TO APPLICATION ROLE app_public;

-- Load operations procedure
CREATE OR REPLACE PROCEDURE core.load_operations()
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
    
    -- Merge data into target table (insert new, update existing)
    MERGE INTO public.operations AS target
    USING (
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
        FROM TABLE(FLATTEN(input => :operation_data:results))
    ) AS source
    ON target.id = source.id
    WHEN MATCHED THEN
        UPDATE SET
            account_id = source.account_id,
            pipeline_run_id = source.pipeline_run_id,
            task_run_id = source.task_run_id,
            inserted_at = source.inserted_at,
            message = source.message,
            operation_name = source.operation_name,
            operation_status = source.operation_status,
            operation_type = source.operation_type,
            external_status = source.external_status,
            external_detail = source.external_detail,
            external_id = source.external_id,
            integration = source.integration,
            integration_job = source.integration_job,
            started_at = source.started_at,
            completed_at = source.completed_at,
            dependencies = source.dependencies,
            operation_duration = source.operation_duration,
            rows_affected = source.rows_affected,
            loaded_at = source.loaded_at
    WHEN NOT MATCHED THEN
        INSERT (
            id, account_id, pipeline_run_id, task_run_id, inserted_at, message,
            operation_name, operation_status, operation_type, external_status,
            external_detail, external_id, integration, integration_job,
            started_at, completed_at, dependencies, operation_duration,
            rows_affected, loaded_at
        )
        VALUES (
            source.id, source.account_id, source.pipeline_run_id, source.task_run_id,
            source.inserted_at, source.message, source.operation_name,
            source.operation_status, source.operation_type, source.external_status,
            source.external_detail, source.external_id, source.integration,
            source.integration_job, source.started_at, source.completed_at,
            source.dependencies, source.operation_duration, source.rows_affected,
            source.loaded_at
        );
    
    -- Get counts for reporting
    SELECT COUNT(*) INTO :insert_count FROM TABLE(FLATTEN(input => :operation_data:results));
    
    RETURN 'Successfully processed ' || :insert_count || ' operations (inserted new or updated existing)';
END;
$$;

GRANT USAGE ON PROCEDURE core.load_operations() TO APPLICATION ROLE app_public;

-- 6. Create tables for storing Orchestra data
CREATE TABLE IF NOT EXISTS public.pipeline_runs (
    id STRING NOT NULL,
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
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_pipeline_runs PRIMARY KEY (id),
    CONSTRAINT uk_pipeline_runs_id UNIQUE (id)
);

CREATE TABLE IF NOT EXISTS public.task_runs (
    id STRING NOT NULL,
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
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_task_runs PRIMARY KEY (id),
    CONSTRAINT uk_task_runs_id UNIQUE (id)
);

CREATE TABLE IF NOT EXISTS public.operations (
    id STRING NOT NULL,
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
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_operations PRIMARY KEY (id),
    CONSTRAINT uk_operations_id UNIQUE (id)
);

-- Grant permissions on tables
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.pipeline_runs TO APPLICATION ROLE app_public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.task_runs TO APPLICATION ROLE app_public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.operations TO APPLICATION ROLE app_public;
