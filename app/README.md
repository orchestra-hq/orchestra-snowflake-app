# Orchestra Data App

This Snowflake Native Application allows you to pull data from the Orchestra API directly into Snowflake using External Access Integration (EAI).

## Features

- **Metadata**: Fetch pipeline runs, task runs and operations metadata directly from the Orchestra API
- **Secure**: API keys are handled securely through Snowflake secrets
- **Easy to Use**: Simple stored procedures for data access

## Getting Started

### Prerequisites

- Snowflake account with appropriate privileges
- Orchestra API key from [https://app.getorchestra.io/settings/api-key](https://app.getorchestra.io/settings/api-key)

### Installation

1. Install the app from the Snowflake Marketplace
2. Grant the External Access Integration reference when prompted
3. Run the setup procedure to create the API access objects

### Setup

After installation, run the following to create the API access objects:

```sql
-- Create the EAI objects (run this after granting the reference)
CALL core.create_eai_objects();
```

## Usage

### Fetch Metadata

```sql
-- Get pipeline runs (replace 'your-api-key' with your actual API key)
SELECT core.get_pipeline_runs('your-api-key', 100);

-- Get task runs
SELECT core.get_task_runs('your-api-key', 100);

-- Get operations
SELECT core.get_operations('your-api-key');
```

### Load Data into Tables

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

-- Load pipeline runs data
CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');
CALL core.load_task_runs_to_table('your-api-key', 'task_runs');
CALL core.load_operations_to_table('your-api-key', 'operations');
```

### Extract Specific Fields

```sql
-- Extract specific fields from pipeline runs
SELECT
    value:id::STRING as pipeline_run_id,
    value:pipeline_id::STRING as pipeline_id,
    value:status::STRING as status,
    value:started_at::TIMESTAMP_NTZ as started_at
FROM TABLE(FLATTEN(input => core.get_pipeline_runs('your-api-key'):pipeline_runs));
```

## Security

- API keys are passed as parameters to procedures (not stored in the app)
- All API calls use HTTPS
- Network access is restricted to app.getorchestra.io
- Proper error handling for failed API calls

## Error Handling

The procedures return error information if API calls fail:

```sql
-- Check for errors
SELECT
    CASE
        WHEN result:error IS NOT NULL THEN 'Error: ' || result:error::STRING
        ELSE 'Success'
    END as status
FROM (SELECT core.get_pipeline_runs('your-api-key') as result);
```

## Support

For support, please contact:

- Email: [support@getorchestra.io](mailto:support@getorchestra.io)
- Documentation: [https://docs.getorchestra.io/docs/metadata-api/overview](https://docs.getorchestra.io/docs/metadata-api/overview)
