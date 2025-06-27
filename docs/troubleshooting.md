# Troubleshooting Guide

This guide helps you resolve common issues when setting up and using the Orchestra Data App with External Access Integration (EAI).

## Common Issues and Solutions

### 1. EAI Reference Not Granted

**Symptoms**:

- Error: "External Access Integration reference not found"
- Error: "EAI reference not granted"
- Error: "Cannot access external API"

**Causes**:

- EAI reference not granted during app installation
- EAI reference was revoked after installation
- App installation incomplete

**Solutions**:

1. **Check EAI Reference Status**:

   ```sql
   -- Check if EAI reference exists
   SHOW EXTERNAL ACCESS INTEGRATIONS;

   -- Check app references
   SELECT * FROM TABLE(INFORMATION_SCHEMA.APPLICATION_REFERENCES());
   ```

2. **Reinstall the App**:

   - Uninstall the Orchestra Data App
   - Reinstall from Snowflake Marketplace
   - Ensure you grant the EAI reference when prompted

3. **Grant EAI Reference Manually**:

   ```sql
   -- Grant the EAI reference (if you have the necessary privileges)
   GRANT USAGE ON EXTERNAL ACCESS INTEGRATION orchestra_api_integration TO APPLICATION ROLE app_public;
   ```

### 2. API Key Issues

**Symptoms**:

- Error: "Authentication failed"
- Error: "Invalid API key"
- Error: "Unauthorized access"

**Causes**:

- Incorrect or expired API key
- API key not properly formatted
- API key doesn't have required permissions

**Solutions**:

1. **Verify API Key**:

   ```bash
   # Test the API key directly
   curl -H "Authorization: Bearer your-api-key-here" \
        https://app.getorchestra.io/api/engine/public/pipeline_runs
   ```

2. **Get a New API Key**:

   - Visit [https://app.getorchestra.io/settings/api-key](https://app.getorchestra.io/settings/api-key)
   - Generate a new API key
   - Ensure the key has the necessary permissions

3. **Test API Key in Snowflake**:

   ```sql
   -- Test the API key with a simple call
   SELECT core.get_pipeline_runs('your-api-key', 1);
   ```

### 3. Procedure Not Found Errors

**Symptoms**:

- Error: "Procedure does not exist"
- Error: "Object not found"
- Error: "core.get_pipeline_runs not found"

**Causes**:

- EAI objects not created after installation
- Procedures created in wrong schema
- Missing procedure permissions

**Solutions**:

1. **Check Procedure Existence**:

   ```sql
   -- List all procedures in the core schema
   SHOW PROCEDURES IN SCHEMA core;

   -- Check specific procedure
   DESCRIBE PROCEDURE core.get_pipeline_runs(STRING, INT);
   ```

2. **Create EAI Objects**:

   ```sql
   -- Create the EAI objects (run this after granting the reference)
   CALL core.create_eai_objects();
   ```

3. **Check Procedure Context**:

   ```sql
   -- Ensure you're in the correct database/schema
   SELECT CURRENT_DATABASE(), CURRENT_SCHEMA();

   -- Use the correct database
   USE DATABASE your_database_name;
   ```

### 4. Network Access Issues

**Symptoms**:

- Error: "Network access denied"
- Error: "Connection timeout"
- Error: "Host not reachable"

**Causes**:

- EAI not properly configured
- Firewall blocking access
- Network rules not applied

**Solutions**:

1. **Check EAI Configuration**:

   ```sql
   -- Verify EAI exists and is enabled
   SHOW EXTERNAL ACCESS INTEGRATIONS;

   -- Check EAI configuration
   DESCRIBE EXTERNAL ACCESS INTEGRATION orchestra_api_integration;
   ```

2. **Check Network Rules**:

   ```sql
   -- Check network rules
   SHOW NETWORK RULES;

   -- Verify network rule allows app.getorchestra.io
   DESCRIBE NETWORK RULE orchestra_api_rule;
   ```

3. **Test Network Connectivity**:

   ```sql
   -- Test basic connectivity
   SELECT SYSTEM$PING('app.getorchestra.io');
   ```

### 5. Rate Limiting Issues

**Symptoms**:

- Error: "Rate limit exceeded"
- Error: "Too many requests"
- Inconsistent API responses

**Causes**:

- Exceeding API rate limits
- No retry logic implemented
- Concurrent requests overwhelming the API

**Solutions**:

1. **Implement Retry Logic**:

   ```sql
   -- Create a procedure with exponential backoff
   CREATE OR REPLACE PROCEDURE safe_api_call_with_retry(api_key STRING)
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
           SELECT core.get_pipeline_runs(:api_key, 10) INTO :result;

           -- Check if rate limited
           IF (result:error_code = 'RATE_LIMIT_EXCEEDED') THEN
               retry_count := retry_count + 1;
               -- Wait with exponential backoff
               CALL SYSTEM$WAIT(SECONDS => POWER(2, retry_count));
           ELSE
               RETURN 'Success after ' || retry_count || ' retries';
           END IF;
       END LOOP;

       RETURN 'Failed after ' || max_retries || ' retries';
   END;
   $$;
   ```

2. **Monitor API Usage**:

   ```sql
   -- Create a monitoring table
   CREATE OR REPLACE TABLE api_usage_log (
       call_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
       procedure_name STRING,
       response_status STRING,
       error_message STRING
   );

   -- Log API calls
   INSERT INTO api_usage_log (procedure_name, response_status, error_message)
   SELECT
       'core.get_pipeline_runs',
       CASE WHEN result:error IS NOT NULL THEN 'ERROR' ELSE 'SUCCESS' END,
       result:error::STRING
   FROM (SELECT core.get_pipeline_runs('your-api-key', 1) as result);
   ```

### 6. Data Parsing Issues

**Symptoms**:

- Error: "Invalid JSON format"
- Error: "Column not found"
- Unexpected NULL values

**Causes**:

- API response format changed
- Incorrect JSON path references
- Missing data in API response

**Solutions**:

1. **Validate API Response**:

   ```sql
   -- Check the raw API response
   SELECT core.get_pipeline_runs('your-api-key', 1) as raw_response;

   -- Validate JSON structure
   SELECT
       IS_VALID_JSON(raw_response) as is_valid,
       OBJECT_KEYS(raw_response) as top_level_keys
   FROM (SELECT core.get_pipeline_runs('your-api-key', 1) as raw_response);
   ```

2. **Safe Data Extraction**:

   ```sql
   -- Use safe extraction with default values
   SELECT
       COALESCE(value:id::STRING, 'UNKNOWN') as pipeline_run_id,
       COALESCE(value:pipeline_id::STRING, 'UNKNOWN') as pipeline_id,
       COALESCE(value:status::STRING, 'UNKNOWN') as status,
       value:started_at::TIMESTAMP_NTZ as started_at
   FROM TABLE(FLATTEN(input => core.get_pipeline_runs('your-api-key'):pipeline_runs));
   ```

3. **Handle Missing Data**:

   ```sql
   -- Check for missing data
   SELECT
       COUNT(*) as total_pipeline_runs,
       COUNT(value:id) as runs_with_id,
       COUNT(value:pipeline_id) as runs_with_pipeline_id,
       COUNT(value:status) as runs_with_status
   FROM TABLE(FLATTEN(input => core.get_pipeline_runs('your-api-key'):pipeline_runs));
   ```

### 7. Performance Issues

**Symptoms**:

- Slow query execution
- Timeout errors
- High resource consumption

**Causes**:

- Large API responses
- No caching implemented
- Inefficient data processing

**Solutions**:

1. **Implement Caching**:

   ```sql
   -- Create cache table
   CREATE OR REPLACE TABLE api_cache (
       endpoint STRING,
       response_data VARIANT,
       cached_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
       expires_at TIMESTAMP_NTZ
   );

   -- Cache function with expiration
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

2. **Optimize Data Processing**:

   ```sql
   -- Process data in smaller chunks
   CREATE OR REPLACE PROCEDURE process_large_dataset(api_key STRING)
   RETURNS STRING
   LANGUAGE SQL
   AS
   $$
   DECLARE
       data VARIANT;
       chunk_size INTEGER DEFAULT 100;
   BEGIN
       SELECT core.get_pipeline_runs(:api_key, 1000) INTO :data;

       -- Process in chunks to avoid memory issues
       FOR i IN 0 TO ARRAY_SIZE(data:pipeline_runs) - 1 STEP :chunk_size LOOP
           -- Process chunk
           INSERT INTO pipeline_runs_table
           SELECT
               value:id::STRING,
               value:pipeline_id::STRING,
               value:status::STRING
           FROM TABLE(FLATTEN(input => ARRAY_SLICE(data:pipeline_runs, i, i + :chunk_size - 1)));
       END FOR;

       RETURN 'Processing completed';
   END;
   $$;
   ```

## Diagnostic Queries

### System Health Check

```sql
-- Comprehensive health check
SELECT
    'EAI Configuration' as check_type,
    CASE
        WHEN EXISTS(SELECT 1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())))
        THEN 'PASS'
        ELSE 'FAIL'
    END as status
FROM (SHOW EXTERNAL ACCESS INTEGRATIONS)
UNION ALL
SELECT
    'Procedure Access' as check_type,
    CASE
        WHEN core.get_pipeline_runs('your-api-key', 1) IS NOT NULL
        THEN 'PASS'
        ELSE 'FAIL'
    END as status
UNION ALL
SELECT
    'Network Connectivity' as check_type,
    CASE
        WHEN SYSTEM$PING('app.getorchestra.io') = 'SUCCESS'
        THEN 'PASS'
        ELSE 'FAIL'
    END as status;
```

### Performance Monitoring

```sql
-- Monitor procedure performance
SELECT
    procedure_name,
    COUNT(*) as call_count,
    AVG(execution_time_ms) as avg_time,
    MAX(execution_time_ms) as max_time,
    COUNT(CASE WHEN error_message IS NOT NULL THEN 1 END) as error_count
FROM api_procedure_logs
WHERE called_at >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY procedure_name
ORDER BY call_count DESC;
```

### Error Analysis

```sql
-- Analyze recent errors
SELECT
    error_message,
    COUNT(*) as error_count,
    MAX(called_at) as last_occurrence
FROM api_procedure_logs
WHERE error_message IS NOT NULL
  AND called_at >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY error_message
ORDER BY error_count DESC;
```

## Getting Help

If you're still experiencing issues after trying these solutions:

1. **Check Snowflake Documentation**: [External Access Integration](https://docs.snowflake.com/en/sql-reference/sql/create-external-access-integration)
2. **Review Orchestra API Documentation**: [https://docs.getorchestra.io/docs/metadata-api/overview](https://docs.getorchestra.io/docs/metadata-api/overview)
3. **Contact Support**:
   - Email: [support@getorchestra.io](mailto:support@getorchestra.io)
   - Include error messages, timestamps, and your Snowflake account information

## Prevention Best Practices

1. **Regular Monitoring**: Set up alerts for API errors and performance issues
2. **Testing**: Test API integration in a development environment first
3. **Documentation**: Keep track of any custom configurations
4. **Backup**: Maintain backup copies of your setup scripts
5. **Updates**: Regularly update API keys and review security settings
