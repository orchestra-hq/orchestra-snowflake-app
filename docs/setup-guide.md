# Setup Guide: Orchestra API Integration with Snowflake Native App

## Understanding Snowflake Native Apps with External Access Integration

### What is External Access Integration (EAI)?

External Access Integration in Snowflake Native Apps allows the application to securely connect to external APIs and services. Unlike traditional external functions that require manual setup, EAI provides a seamless way for Native Apps to access external data.

### How EAI Works

1. **EAI Reference**: Defined in the app manifest, specifies which external endpoints can be accessed
2. **Configuration Callback**: Returns the configuration for the EAI (host_ports, allowed_secrets)
3. **Register Callback**: Handles the binding of the EAI reference
4. **Python Procedures**: Stored procedures that use the EAI to call external APIs
5. **Secure API Key Handling**: API keys are passed as parameters, not stored in the app

### Why EAI is Better Than Manual External Functions

Snowflake Native Apps with EAI provide several advantages over manual external function setup:

1. **Simplified Setup**: No manual network configuration required
2. **Built-in Security**: API keys handled securely through the app
3. **Automatic Network Access**: EAI handles network configuration
4. **Better Error Handling**: Comprehensive error handling built into the app
5. **Easier Maintenance**: App manages all API integration aspects

## Prerequisites

Before setting up the Orchestra Data App, ensure you have:

- **Snowflake Account**: Access to a Snowflake account with appropriate privileges
- **Orchestra API Key**: Your API key from [https://app.getorchestra.io/settings/api-key](https://app.getorchestra.io/settings/api-key)
- **App Installation Privileges**: Ability to install and configure Native Apps

## Step-by-Step Setup

### Step 1: Install the Native App

1. Navigate to the Snowflake Marketplace
2. Search for "Orchestra Data App"
3. Click "Get" to install the app
4. Follow the installation wizard

### Step 2: Grant External Access Integration Reference

During installation, you'll be prompted to grant the External Access Integration reference:

1. **Review the Reference**: The app will request access to `app.getorchestra.io`
2. **Grant Permissions**: Click "Grant" to allow the app to access the Orchestra API
3. **Confirm Setup**: The EAI will be automatically configured

### Step 3: Create API Access Objects

After installation, run the setup procedure to create the API access objects:

```sql
-- Create the EAI objects (run this after granting the reference)
CALL core.create_eai_objects();
```

This procedure creates the following stored procedures:

- `core.get_pipeline_runs()` - Fetch pipeline execution data
- `core.get_task_runs()` - Fetch task execution data
- `core.get_operations()` - Fetch operations data

### Step 4: Test the Setup

Verify the setup works correctly:

```sql
-- Test the API connection (replace with your actual API key)
SELECT core.get_pipeline_runs('your-api-key', 10);
```

## Using the Orchestra Data App

### Basic Usage

```sql
-- Fetch pipeline runs
SELECT core.get_pipeline_runs('your-api-key', 100);

-- Fetch task runs
SELECT core.get_task_runs('your-api-key', 100);

-- Fetch operations
SELECT core.get_operations('your-api-key');
```

### Store Data in Tables

```sql
-- Create a table to store pipeline runs
CREATE TABLE pipeline_runs (
    pipeline_run_id STRING,
    pipeline_id STRING,
    status STRING,
    started_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    raw_data VARIANT,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create a table to store task runs
CREATE TABLE task_runs (
    task_run_id STRING,
    task_id STRING,
    status STRING,
    started_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    raw_data VARIANT,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create a table to store operations
CREATE TABLE operations (
    operation_id STRING,
    operation_name STRING,
    operation_type STRING,
    operation_status STRING,
    operation_started_at TIMESTAMP_NTZ,
    operation_completed_at TIMESTAMP_NTZ,
    operation_created_at TIMESTAMP_NTZ,
    operation_updated_at TIMESTAMP_NTZ,
    operation_raw_data VARIANT,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Load data using helper procedures
CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');
CALL core.load_task_runs_to_table('your-api-key', 'task_runs');
CALL core.load_operations_to_table('your-api-key', 'operations');
```

### Schedule Regular Updates

```sql
-- Create a task to refresh data daily
CREATE OR REPLACE TASK refresh_orchestra_data
  WAREHOUSE = your_warehouse
  SCHEDULE = 'USING CRON 0 2 * * * UTC'  -- Daily at 2 AM UTC
AS
  BEGIN
    CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');
    CALL core.load_task_runs_to_table('your-api-key', 'task_runs');
    CALL core.load_operations_to_table('your-api-key', 'operations');
  END;

-- Resume the task
ALTER TASK refresh_orchestra_data RESUME;
```

## Security Considerations

### API Key Management

1. **Parameter Passing**: API keys are passed as parameters to procedures, not stored in the app
2. **No Persistent Storage**: Keys are not stored in Snowflake secrets or tables
3. **Secure Transmission**: All API calls use HTTPS with proper authentication
4. **Access Control**: Use Snowflake's role-based access control to limit who can access the procedures

### Network Security

1. **EAI Configuration**: Network access is automatically configured through the EAI
2. **HTTPS Only**: All API calls use HTTPS to app.getorchestra.io
3. **Audit Logging**: Monitor API usage through Snowflake's audit logs
4. **Restricted Access**: Access is limited to only the required Orchestra API endpoints

### Data Protection

1. **Encryption**: All data is encrypted in transit and at rest
2. **Access Control**: Use Snowflake's role-based access control
3. **Data Retention**: Implement appropriate data retention policies
4. **Audit Trail**: Maintain logs of all API calls and data access

## Troubleshooting

### Common Issues

1. **EAI Reference Not Granted**: Ensure you granted the External Access Integration reference during installation
2. **API Key Invalid**: Verify your API key is correct and not expired
3. **Network Access Denied**: Check that the EAI was properly configured
4. **Procedure Not Found**: Ensure you ran `CALL core.create_eai_objects();` after installation

### Debugging

```sql
-- Check if EAI objects were created
SHOW PROCEDURES IN SCHEMA core;

-- Test API connectivity
SELECT core.get_pipeline_runs('your-api-key', 1);

-- Check for errors in API responses
SELECT
    CASE
        WHEN result:error IS NOT NULL THEN 'Error: ' || result:error::STRING
        ELSE 'Success'
    END as status
FROM (SELECT core.get_pipeline_runs('your-api-key', 1) as result);
```

## Next Steps

After completing the setup:

1. **Explore the Data**: Use the procedures to explore your Orchestra data
2. **Create Views**: Build views for common data access patterns
3. **Set up Monitoring**: Monitor API usage and data freshness
4. **Automate**: Create tasks for regular data synchronization

For additional help, see the [Examples](examples.md) and [API Reference](api-reference.md) documentation.
