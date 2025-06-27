# Examples: Using Orchestra Data App Procedures

This document provides practical examples of how to use the Orchestra Data App procedures to fetch and work with your Orchestra data in Snowflake.

## Basic Procedure Usage

### Fetch Pipeline Runs Data

```sql
-- Basic call to get pipeline runs
SELECT core.get_pipeline_runs('your-api-key', 100);

-- Extract specific fields from the response
SELECT
    value:id::STRING as id,
    value:pipeline_id::STRING as pipeline_id,
    value:pipeline_name::STRING as pipeline_name,
    value:run_status::STRING as run_status,
    value:started_at::TIMESTAMP_NTZ as started_at,
    value:completed_at::TIMESTAMP_NTZ as completed_at
FROM TABLE(FLATTEN(input => core.get_pipeline_runs('your-api-key'):pipeline_runs));
```

### Fetch Task Runs Data

```sql
-- Get task runs
SELECT core.get_task_runs('your-api-key', 100);

-- Extract task run information
SELECT
    value:id::STRING as id,
    value:pipeline_run_id::STRING as pipeline_run_id,
    value:task_name::STRING as task_name,
    value:task_id::STRING as task_id,
    value:status::STRING as status,
    value:started_at::TIMESTAMP_NTZ as started_at,
    value:completed_at::TIMESTAMP_NTZ as completed_at
FROM TABLE(FLATTEN(input => core.get_task_runs('your-api-key'):task_runs));
```

### Fetch Operations Data

```sql
-- Get operations
SELECT core.get_operations('your-api-key');

-- Extract operation information
SELECT
    value:id::STRING as id,
    value:operation_name::STRING as operation_name,
    value:operation_type::STRING as operation_type,
    value:operation_status::STRING as operation_status,
    value:started_at::TIMESTAMP_NTZ as started_at,
    value:completed_at::TIMESTAMP_NTZ as completed_at
FROM TABLE(FLATTEN(input => core.get_operations('your-api-key'):operations));
```

## Data Loading Examples

### Load Pipeline Runs into Table

```sql
-- Create a table to store pipeline runs
CREATE TABLE pipeline_runs (
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

-- Load pipeline runs data using helper procedure
CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');
```

### Load Task Runs into Table

```sql
-- Create a table to store task runs
CREATE TABLE task_runs (
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

-- Load task runs data using helper procedure
CALL core.load_task_runs_to_table('your-api-key', 'task_runs');
```

### Load Operations into Table

```sql
-- Create a table to store operations
CREATE TABLE operations (
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

-- Load operations data using helper procedure
CALL core.load_operations_to_table('your-api-key', 'operations');
```

## Data Analysis Examples

### Pipeline Run Analysis

```sql
-- Get a summary of pipeline runs by status
SELECT
    run_status,
    COUNT(*) as run_count,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes,
    MIN(started_at) as earliest_run,
    MAX(started_at) as latest_run
FROM pipeline_runs
WHERE completed_at IS NOT NULL
GROUP BY run_status
ORDER BY run_count DESC;
```

### Task Run Performance Analysis

```sql
-- Analyze task run performance
SELECT
    task_id,
    COUNT(*) as total_runs,
    COUNT(CASE WHEN status = 'SUCCEEDED' THEN 1 END) as successful_runs,
    COUNT(CASE WHEN status = 'FAILED' THEN 1 END) as failed_runs,
    AVG(DATEDIFF('second', started_at, completed_at)) as avg_duration_seconds,
    ROUND(COUNT(CASE WHEN status = 'SUCCEEDED' THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate
FROM task_runs
WHERE completed_at IS NOT NULL
GROUP BY task_id
ORDER BY total_runs DESC;
```

### Operations Overview

```sql
-- Get operations summary
SELECT
    operation_type,
    operation_status,
    COUNT(*) as operation_count,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes
FROM operations
WHERE completed_at IS NOT NULL
GROUP BY operation_type, operation_status
ORDER BY operation_count DESC;
```

### Pipeline and Task Correlation

```sql
-- Correlate pipeline runs with task runs
SELECT
    pr.pipeline_id,
    pr.run_status as pipeline_status,
    COUNT(tr.id) as task_count,
    COUNT(CASE WHEN tr.status = 'SUCCEEDED' THEN 1 END) as successful_tasks,
    COUNT(CASE WHEN tr.status = 'FAILED' THEN 1 END) as failed_tasks
FROM pipeline_runs pr
LEFT JOIN task_runs tr ON pr.pipeline_id = tr.pipeline_id
GROUP BY pr.pipeline_id, pr.run_status
ORDER BY task_count DESC;
```

## Automation Examples

### Create a Stored Procedure for Data Refresh

```sql
CREATE OR REPLACE PROCEDURE refresh_orchestra_data(api_key STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    pipeline_count INTEGER;
    task_count INTEGER;
    operation_count INTEGER;
BEGIN
    -- Refresh pipeline runs
    DELETE FROM pipeline_runs;
    CALL core.load_pipeline_runs_to_table(:api_key, 'pipeline_runs');
    SELECT COUNT(*) INTO :pipeline_count FROM pipeline_runs;

    -- Refresh task runs
    DELETE FROM task_runs;
    CALL core.load_task_runs_to_table(:api_key, 'task_runs');
    SELECT COUNT(*) INTO :task_count FROM task_runs;

    -- Refresh operations
    DELETE FROM operations;
    CALL core.load_operations_to_table(:api_key, 'operations');
    SELECT COUNT(*) INTO :operation_count FROM operations;

    RETURN 'Refresh completed: ' || :pipeline_count || ' pipeline runs, ' || :task_count || ' task runs, ' || :operation_count || ' operations';
END;
$$;
```

### Create Scheduled Tasks

```sql
-- Task to refresh data daily at 2 AM UTC
CREATE OR REPLACE TASK refresh_orchestra_data_daily
  WAREHOUSE = your_warehouse
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
AS
  CALL refresh_orchestra_data('your-api-key');

-- Task to refresh data every hour during business hours
CREATE OR REPLACE TASK refresh_orchestra_data_hourly
  WAREHOUSE = your_warehouse
  SCHEDULE = 'USING CRON 0 9-17 * * 1-5 UTC'  -- 9 AM to 5 PM UTC, Mon-Fri
AS
  CALL refresh_orchestra_data('your-api-key');

-- Resume the tasks
ALTER TASK refresh_orchestra_data_daily RESUME;
ALTER TASK refresh_orchestra_data_hourly RESUME;
```

## Advanced Query Examples

### Find Failed Pipeline Runs

```sql
-- Find all failed pipeline runs with their details
SELECT
    id,
    pipeline_id,
    pipeline_name,
    run_status,
    started_at,
    completed_at,
    DATEDIFF('minute', started_at, completed_at) as duration_minutes,
    message
FROM pipeline_runs
WHERE run_status = 'FAILED'
ORDER BY started_at DESC;
```

### Pipeline Performance Trends

```sql
-- Analyze pipeline performance over time
SELECT
    DATE_TRUNC('day', started_at) as run_date,
    COUNT(*) as total_runs,
    COUNT(CASE WHEN run_status = 'SUCCEEDED' THEN 1 END) as successful_runs,
    COUNT(CASE WHEN run_status = 'FAILED' THEN 1 END) as failed_runs,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes,
    ROUND(COUNT(CASE WHEN run_status = 'SUCCEEDED' THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate
FROM pipeline_runs
WHERE started_at >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY DATE_TRUNC('day', started_at)
ORDER BY run_date DESC;
```

### Task Run Dependencies

```sql
-- Analyze task run dependencies and timing
SELECT
    task_id,
    task_name,
    COUNT(*) as total_runs,
    AVG(DATEDIFF('second', started_at, completed_at)) as avg_duration_seconds,
    MIN(started_at) as first_run,
    MAX(started_at) as last_run,
    COUNT(DISTINCT DATE_TRUNC('day', started_at)) as active_days
FROM task_runs
WHERE completed_at IS NOT NULL
GROUP BY task_id, task_name
HAVING COUNT(*) > 5  -- Only tasks with more than 5 runs
ORDER BY total_runs DESC;
```

### Data Freshness Monitoring

```sql
-- Monitor data freshness
SELECT
    'pipeline_runs' as table_name,
    COUNT(*) as record_count,
    MAX(loaded_at) as last_loaded,
    DATEDIFF('minute', MAX(loaded_at), CURRENT_TIMESTAMP()) as minutes_since_last_load
FROM pipeline_runs
UNION ALL
SELECT
    'task_runs' as table_name,
    COUNT(*) as record_count,
    MAX(loaded_at) as last_loaded,
    DATEDIFF('minute', MAX(loaded_at), CURRENT_TIMESTAMP()) as minutes_since_last_load
FROM task_runs
UNION ALL
SELECT
    'operations' as table_name,
    COUNT(*) as record_count,
    MAX(loaded_at) as last_loaded,
    DATEDIFF('minute', MAX(loaded_at), CURRENT_TIMESTAMP()) as minutes_since_last_load
FROM operations;
```

## Error Handling Examples

### Safe Data Loading with Error Handling

```sql
-- Create a procedure with error handling
CREATE OR REPLACE PROCEDURE safe_load_pipeline_runs(api_key STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result VARIANT;
    error_message STRING;
BEGIN
    -- Try to fetch data from API
    SELECT core.get_pipeline_runs(:api_key, 100) INTO :result;

    -- Check if the API call was successful
    IF (result:error IS NOT NULL) THEN
        error_message := 'API Error: ' || result:error::STRING;
        RETURN error_message;
    END IF;

    -- Load data if successful
    INSERT INTO pipeline_runs
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
    FROM TABLE(FLATTEN(input => result:pipeline_runs));

    RETURN 'Successfully loaded ' || ARRAY_SIZE(result:pipeline_runs) || ' pipeline runs';

EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error: ' || SQLERRM;
END;
$$;
```

## Performance Optimization Examples

### Partitioned Tables for Large Datasets

```sql
-- Create a partitioned table for better performance with large datasets
CREATE OR REPLACE TABLE pipeline_runs_partitioned (
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
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    partition_date DATE DEFAULT CURRENT_DATE()
)
CLUSTER BY (partition_date, run_status);

-- Insert data with partitioning
INSERT INTO pipeline_runs_partitioned
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
    CURRENT_DATE() as partition_date
FROM TABLE(FLATTEN(input => core.get_pipeline_runs('your-api-key'):pipeline_runs));
```

### Materialized Views for Common Queries

```sql
-- Create a materialized view for pipeline run summaries
CREATE OR REPLACE MATERIALIZED VIEW pipeline_run_summary AS
SELECT
    pipeline_id,
    pipeline_name,
    COUNT(*) as total_runs,
    COUNT(CASE WHEN run_status = 'SUCCEEDED' THEN 1 END) as successful_runs,
    COUNT(CASE WHEN run_status = 'FAILED' THEN 1 END) as failed_runs,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes,
    MAX(started_at) as last_run
FROM pipeline_runs
WHERE completed_at IS NOT NULL
GROUP BY pipeline_id, pipeline_name;

-- Refresh the materialized view
ALTER MATERIALIZED VIEW pipeline_run_summary REFRESH;
```

These examples demonstrate the flexibility and power of using the Orchestra Data App procedures to integrate with the Orchestra API. You can adapt these patterns to work with other Orchestra API endpoints and create custom solutions for your specific use cases.
