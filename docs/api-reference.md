# API Reference: Orchestra Data App Procedures

This document provides a complete reference for all available stored procedures in the Orchestra Data App that connect to the Orchestra API using External Access Integration (EAI).

## Procedure Overview

All procedures return data in JSON format (VARIANT type) and require an Orchestra API key as a parameter. The procedures use Snowflake's External Access Integration to securely connect to the Orchestra API.

## Available Procedures

### core.get_pipeline_runs()

Fetches pipeline runs from the Orchestra API.

**Parameters**:

- `api_key` (STRING): Your Orchestra API key
- `limit` (INT, optional): Maximum number of pipeline runs to fetch (default: 100)

**Returns**: VARIANT (JSON object containing pipeline runs array)

**Example Response Structure**:

```json
{
  "pipeline_runs": [
    {
      "id": "286cb489-54f0-499b-b531-b84e3909ac9b",
      "pipelineId": "c43ca283-6908-4769-a145-a439401f1837",
      "pipelineName": "My test pipeline",
      "accountId": "84e75049-b4c3-4a93-a595-21cff92bdb9d",
      "envId": "398945f0-e5ef-4d5a-9698-0b751ad060d0",
      "envName": "Production",
      "runStatus": "SUCCEEDED",
      "triggeredBy": [
        {
          "triggerType": "SENSOR",
          "sensorName": "Test conditional",
          "sensorRunId": "65941b4b-f2d0-405a-ae4b-9d3093165655"
        }
      ],
      "childPipelineRuns": [],
      "message": "All tasks have succeeded.",
      "createdAt": "2025-05-01T11:16:39.421992+00:00",
      "updatedAt": "2025-05-01T11:17:01.421626+00:00",
      "completedAt": "2025-05-01T11:17:01.280976+00:00",
      "startedAt": "2025-05-01T11:16:44.841252+00:00",
      "branch": "main",
      "commit": "8cf1f2aea901d8316c694b92bbcfd05ce1e75e5d",
      "pipelineVersionNumber": 1
    }
  ]
}
```

**Usage**:

```sql
-- Basic usage
SELECT core.get_pipeline_runs('your-api-key');

-- With limit parameter
SELECT core.get_pipeline_runs('your-api-key', 50);

-- Extract specific fields
SELECT
    value:id::STRING as id,
    value:pipeline_id::STRING as pipeline_id,
    value:pipeline_name::STRING as pipeline_name,
    value:run_status::STRING as run_status,
    value:started_at::TIMESTAMP_NTZ as started_at,
    value:completed_at::TIMESTAMP_NTZ as completed_at
FROM TABLE(FLATTEN(input => core.get_pipeline_runs('your-api-key'):pipeline_runs));
```

### core.get_task_runs()

Fetches task runs from the Orchestra API.

**Parameters**:

- `api_key` (STRING): Your Orchestra API key
- `limit` (INT, optional): Maximum number of task runs to fetch (default: 100)

**Returns**: VARIANT (JSON object containing task runs array)

**Example Response Structure**:

```json
{
  "task_runs": [
    {
      "id": "3d68b5dc-54eb-43db-8294-4734d032ff92",
      "pipelineRunId": "d4159d06-4366-4fd7-b74e-d30b4a10565a",
      "taskName": "Task A",
      "taskId": "task_a",
      "accountId": "84e75049-b4c3-4a93-a595-21cff92bdb9d",
      "pipelineId": "31448365-f08b-4945-beed-5344bd4d16ed",
      "integration": "HTTP",
      "integrationJob": "HTTP_REQUEST",
      "status": "SUCCEEDED",
      "message": "OK",
      "externalStatus": "200",
      "externalMessage": "200 OK",
      "platformLink": "https://platform_link.io/run_id",
      "taskParameters": {
        "path": "/200",
        "method": "GET",
        "set_outputs": false
      },
      "runParameters": {
        "url": "https://httpstat.us/200"
      },
      "connectionId": "http_request_83638",
      "numberOfAttempts": 1,
      "createdAt": "2025-04-27T08:00:35.323704+00:00",
      "updatedAt": "2025-04-27T08:00:57.122547+00:00",
      "completedAt": "2025-04-27T08:00:56.867938+00:00",
      "startedAt": "2025-04-27T08:00:56.748405+00:00"
    }
  ]
}
```

**Usage**:

```sql
-- Basic usage
SELECT core.get_task_runs('your-api-key');

-- With limit parameter
SELECT core.get_task_runs('your-api-key', 200);

-- Extract specific fields
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

### core.get_operations()

Fetches operations from the Orchestra API.

**Parameters**:

- `api_key` (STRING): Your Orchestra API key

**Returns**: VARIANT (JSON object containing operations array)

**Example Response Structure**:

```json
{
  "operations": [
    {
      "id": "35f89337-91fd-4a80-9b7a-2d84a917b4ec",
      "accountId": "84e75049-b4c3-4a93-a595-21cff92bdb9d",
      "pipelineRunId": "2585e1f7-1713-4db7-bfab-0c840082d84b",
      "taskRunId": "734d5cbb-a765-4425-bad7-a7c5691d1fe1",
      "insertedAt": "2025-05-01T10:24:47.250401+00:00",
      "message": "Query succeeded",
      "operationName": "01bc0e10-0000-92c4-0000-403501419306",
      "operationStatus": "SUCCEEDED",
      "operationType": "QUERY",
      "externalStatus": "SUCCESS",
      "externalDetail": "SELECT 1 FROM TEST LIMIT 1;",
      "externalId": "01bc0e10-0000-92c4-0000-403501419306",
      "integration": "SNOWFLAKE",
      "integrationJob": "SNOWFLAKE_RUN_QUERY",
      "startedAt": "2025-05-01T10:24:27.154000+00:00",
      "completedAt": "2025-05-01T10:24:27.326000+00:00",
      "dependencies": [],
      "operationDuration": 0.17,
      "rowsAffected": 1
    }
  ]
}
```

**Usage**:

```sql
-- Basic usage
SELECT core.get_operations('your-api-key');

-- Extract specific fields
SELECT
    value:id::STRING as id,
    value:operation_name::STRING as operation_name,
    value:operation_type::STRING as operation_type,
    value:operation_status::STRING as operation_status,
    value:started_at::TIMESTAMP_NTZ as started_at,
    value:completed_at::TIMESTAMP_NTZ as completed_at
FROM TABLE(FLATTEN(input => core.get_operations('your-api-key'):operations));
```

### core.load_pipeline_runs_to_table()

Loads pipeline runs data into a specified table.

**Parameters**:

- `api_key` (STRING): Your Orchestra API key
- `target_table` (STRING): Name of the table to load data into

**Returns**: STRING (Success message with count of loaded records)

**Usage**:

```sql
-- Load pipeline runs into a table
CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');
```

### core.load_task_runs_to_table()

Loads task runs data into a specified table.

**Parameters**:

- `api_key` (STRING): Your Orchestra API key
- `target_table` (STRING): Name of the table to load data into

**Returns**: STRING (Success message with count of loaded records)

**Usage**:

```sql
-- Load task runs into a table
CALL core.load_task_runs_to_table('your-api-key', 'task_runs');
```

### core.load_operations_to_table()

Loads operations data into a specified table.

**Parameters**:

- `api_key` (STRING): Your Orchestra API key
- `target_table` (STRING): Name of the table to load data into

**Returns**: STRING (Success message with count of loaded records)

**Usage**:

```sql
-- Load operations into a table
CALL core.load_operations_to_table('your-api-key', 'operations');
```

## Error Handling

All procedures may return error responses in the following format:

```json
{
  "error": "Error message describing the issue",
  "error_code": "ERROR_CODE",
  "pipeline_runs": [],
  "task_runs": [],
  "operations": []
}
```

**Common Error Codes**:

- `AUTHENTICATION_FAILED`: Invalid or expired API key
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `ENDPOINT_NOT_FOUND`: Invalid API endpoint
- `INTERNAL_ERROR`: Server-side error
- `API_ERROR`: General API error

**Error Handling Example**:

```sql
-- Check for errors in the response
SELECT
    CASE
        WHEN result:error IS NOT NULL THEN 'Error: ' || result:error::STRING
        ELSE 'Success'
    END as status,
    result
FROM (
    SELECT core.get_pipeline_runs('your-api-key') as result
);
```

## Rate Limiting

The Orchestra API implements rate limiting to ensure fair usage:

- **Rate Limit**: Varies by API key tier
- **Burst Limit**: Varies by API key tier
- **Headers**: Rate limit information is included in response headers

**Rate Limit Handling**:

```sql
-- Implement exponential backoff for rate limit errors
CREATE OR REPLACE PROCEDURE safe_api_call_with_retry()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result VARIANT;
    retry_count INTEGER DEFAULT 0;
    max_retries INTEGER DEFAULT 3;
BEGIN
    WHILE (retry_count < max_retries) LOOP
        SELECT core.get_pipeline_runs('your-api-key') INTO :result;

        -- Check if rate limited
        IF (result:error_code = 'RATE_LIMIT_EXCEEDED') THEN
            retry_count := retry_count + 1;
            -- Wait with exponential backoff (2^retry_count seconds)
            CALL SYSTEM$WAIT(SECONDS => POWER(2, retry_count));
        ELSE
            RETURN 'Success after ' || retry_count || ' retries';
        END IF;
    END LOOP;

    RETURN 'Failed after ' || max_retries || ' retries';
END;
$$;
```

## Authentication

All procedures require an Orchestra API key passed as a parameter.

**Getting an API Key**:

1. Log in to [https://app.getorchestra.io/settings/api-key](https://app.getorchestra.io/settings/api-key)
2. Generate a new API key
3. Use the key as the `api_key` parameter in procedure calls

**Security Best Practices**:

- Never hardcode API keys in SQL scripts
- Use Snowflake variables or parameters to pass API keys
- Rotate API keys regularly
- Use the principle of least privilege

## Performance Considerations

### Caching

Consider implementing caching strategies to reduce API calls:

```sql
-- Create a cache table
CREATE OR REPLACE TABLE api_cache (
    endpoint STRING,
    response_data VARIANT,
    cached_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    expires_at TIMESTAMP_NTZ
);

-- Function to get cached data or fetch from API
CREATE OR REPLACE FUNCTION get_cached_pipeline_runs(api_key STRING)
RETURNS VARIANT
AS
$$
SELECT
    CASE
        WHEN cached.response_data IS NOT NULL AND cached.expires_at > CURRENT_TIMESTAMP()
        THEN cached.response_data
        ELSE core.get_pipeline_runs(:api_key)
    END
FROM (
    SELECT response_data, expires_at
    FROM api_cache
    WHERE endpoint = 'pipeline_runs'
    ORDER BY cached_at DESC
    LIMIT 1
) cached;
$$;
```

### Batch Processing

For large datasets, consider implementing batch processing:

```sql
-- Process data in batches
CREATE OR REPLACE PROCEDURE process_pipeline_runs_in_batches(api_key STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    pipeline_data VARIANT;
    batch_size INTEGER DEFAULT 100;
    total_processed INTEGER DEFAULT 0;
BEGIN
    SELECT core.get_pipeline_runs(:api_key, 1000) INTO :pipeline_data;

    -- Process pipeline runs in batches
    FOR i IN 0 TO ARRAY_SIZE(pipeline_data:pipeline_runs) - 1 STEP :batch_size LOOP
        -- Process batch from index i to i + batch_size - 1
        INSERT INTO pipeline_runs_table
        SELECT
            value:id::STRING,
            value:pipeline_id::STRING,
            value:status::STRING,
            value:started_at::TIMESTAMP_NTZ,
            value:completed_at::TIMESTAMP_NTZ,
            value:created_at::TIMESTAMP_NTZ,
            value:updated_at::TIMESTAMP_NTZ,
            value as raw_data
        FROM TABLE(FLATTEN(input => ARRAY_SLICE(pipeline_data:pipeline_runs, i, i + :batch_size - 1)));

        total_processed := total_processed + LEAST(:batch_size, ARRAY_SIZE(pipeline_data:pipeline_runs) - i);
    END FOR;

    RETURN 'Processed ' || total_processed || ' pipeline runs in batches';
END;
$$;
```

## Monitoring and Logging

### Procedure Usage Monitoring

```sql
-- Create a monitoring table
CREATE OR REPLACE TABLE api_procedure_logs (
    procedure_name STRING,
    called_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    response_size INTEGER,
    execution_time_ms INTEGER,
    error_message STRING
);

-- Log procedure calls
CREATE OR REPLACE PROCEDURE log_api_call(procedure_name STRING, response VARIANT, execution_time INTEGER)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO api_procedure_logs (
        procedure_name,
        response_size,
        execution_time_ms,
        error_message
    )
    SELECT
        :procedure_name,
        OBJECT_KEYS(:response):size,
        :execution_time,
        :response:error::STRING
    WHERE :response:error IS NOT NULL;

    RETURN 'Logged API call';
END;
$$;
```

### Performance Metrics

```sql
-- Get performance metrics
SELECT
    procedure_name,
    COUNT(*) as call_count,
    AVG(execution_time_ms) as avg_execution_time,
    MAX(execution_time_ms) as max_execution_time,
    COUNT(CASE WHEN error_message IS NOT NULL THEN 1 END) as error_count
FROM api_procedure_logs
WHERE called_at >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY procedure_name
ORDER BY call_count DESC;
```

## Best Practices

1. **Error Handling**: Always check for errors in API responses
2. **Rate Limiting**: Implement retry logic with exponential backoff
3. **Caching**: Cache frequently accessed data to reduce API calls
4. **Monitoring**: Log procedure calls and monitor performance
5. **Batch Processing**: Process large datasets in batches
6. **Security**: Keep API keys secure and rotate them regularly

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Verify API key is correct and not expired
2. **Network Errors**: Check that the EAI was properly configured
3. **Rate Limiting**: Implement proper retry logic
4. **Data Parsing**: Verify JSON structure matches expected format

### Debug Queries

```sql
-- Check if procedures exist
SHOW PROCEDURES IN SCHEMA core;

-- Test basic procedure call
SELECT core.get_pipeline_runs('your-api-key', 1);

-- Check EAI configuration
SHOW EXTERNAL ACCESS INTEGRATIONS;
```

For additional support, refer to the [Setup Guide](setup-guide.md) and [Examples](examples.md) documentation.
