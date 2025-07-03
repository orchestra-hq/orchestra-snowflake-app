# Orchestra Data App

This Snowflake Native Application allows you to pull data from the Orchestra API directly into Snowflake using External Access Integration (EAI).

## Features

- **Metadata**: Fetch pipeline runs, task runs and operations metadata directly from the Orchestra API
- **Secure**: API keys are handled securely through Snowflake secrets
- **Easy to Use**: Simple stored procedures for data access
- **Automatic Data Loading**: Built-in procedures to load data directly into tables

## Prerequisites

The app will automatically create tables in the `<APP_NAME>.PUBLIC` schema when you run the setup procedures.

### Other Prerequisites

- Snowflake account with appropriate privileges
- Orchestra API key from [https://app.getorchestra.io/settings/api-key](https://app.getorchestra.io/settings/api-key)

## Getting Started

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

This procedure creates the necessary stored procedures that can access the Orchestra API using the configured External Access Integration.

## Usage

### Fetch Metadata

The app provides three main procedures to fetch data from the Orchestra API:

```sql
-- Get pipeline runs (defaults to page 1, 100 results per page)
SELECT core.get_pipeline_runs();

-- Get task runs (defaults to page 1, 100 results per page)
SELECT core.get_task_runs();

-- Get operations (defaults to page 1, 100 results per page)
SELECT core.get_operations();
```

You can also specify custom pagination:

```sql
-- Get pipeline runs with custom pagination
SELECT core.get_pipeline_runs(2, 50);  -- page 2, 50 results per page
```

### Load Data into Tables

The app automatically creates the following tables in the `public` schema:

- `pipeline_runs` - Stores pipeline run metadata
- `task_runs` - Stores task run metadata
- `operations` - Stores operation metadata

To load data into these tables:

```sql
-- Load pipeline runs data
CALL core.load_pipeline_runs();

-- Load task runs data
CALL core.load_task_runs();

-- Load operations data
CALL core.load_operations();
```

Each procedure will:

1. Fetch the latest data from the Orchestra API
2. Transform the data to match the table schema
3. Insert the data into the corresponding table
4. Return a success message with the number of records loaded

### Extract Specific Fields

```sql
-- Extract specific fields from pipeline runs
SELECT
    value:id::STRING as pipeline_run_id,
    value:pipelineId::STRING as pipeline_id,
    value:runStatus::STRING as status,
    value:startedAt::TIMESTAMP_NTZ as started_at
FROM TABLE(FLATTEN(input => core.get_pipeline_runs():results));
```

### Query the Loaded Data

Once data is loaded into tables, you can query it directly:

```sql
-- Query pipeline runs
SELECT * FROM public.pipeline_runs ORDER BY created_at DESC;

-- Query task runs with status filter
SELECT * FROM public.task_runs WHERE status = 'SUCCESS';

-- Query operations for a specific pipeline run
SELECT * FROM public.operations WHERE pipeline_run_id = 'your-pipeline-run-id';
```

## Security

- API keys are handled securely through Snowflake secrets
- All API calls use HTTPS
- Network access is restricted to app.getorchestra.io
- Proper error handling for failed API calls
- External Access Integration ensures secure external API access

## Error Handling

The procedures return error information if API calls fail:

```sql
-- Check for errors in API response
SELECT
    CASE
        WHEN result:error IS NOT NULL THEN 'Error: ' || result:error::STRING
        ELSE 'Success'
    END as status
FROM (SELECT core.get_pipeline_runs() as result);
```

## Table Schemas

### Pipeline Runs Table

- `id` - Unique pipeline run identifier
- `pipeline_id` - Pipeline identifier
- `pipeline_name` - Name of the pipeline
- `account_id` - Account identifier
- `env_id` - Environment identifier
- `env_name` - Environment name
- `run_status` - Status of the pipeline run
- `message` - Status message
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp
- `completed_at` - Completion timestamp
- `started_at` - Start timestamp
- `branch` - Git branch
- `commit` - Git commit hash
- `pipeline_version_number` - Pipeline version
- `loaded_at` - When the record was loaded into Snowflake

### Task Runs Table

- `id` - Unique task run identifier
- `pipeline_run_id` - Associated pipeline run
- `task_name` - Name of the task
- `task_id` - Task identifier
- `account_id` - Account identifier
- `pipeline_id` - Pipeline identifier
- `integration` - Integration type
- `integration_job` - Integration job name
- `status` - Task status
- `message` - Status message
- `external_status` - External system status
- `external_message` - External system message
- `platform_link` - Link to external platform
- `task_parameters` - Task parameters (VARIANT)
- `run_parameters` - Run parameters (VARIANT)
- `connection_id` - Connection identifier
- `number_of_attempts` - Number of execution attempts
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp
- `completed_at` - Completion timestamp
- `started_at` - Start timestamp
- `loaded_at` - When the record was loaded into Snowflake

### Operations Table

- `id` - Unique operation identifier
- `account_id` - Account identifier
- `pipeline_run_id` - Associated pipeline run
- `task_run_id` - Associated task run
- `inserted_at` - Insertion timestamp
- `message` - Operation message
- `operation_name` - Name of the operation
- `operation_status` - Operation status
- `operation_type` - Type of operation
- `external_status` - External system status
- `external_detail` - External system details
- `external_id` - External system identifier
- `integration` - Integration type
- `integration_job` - Integration job name
- `started_at` - Start timestamp
- `completed_at` - Completion timestamp
- `dependencies` - Operation dependencies (VARIANT)
- `operation_duration` - Duration in seconds
- `rows_affected` - Number of rows affected
- `loaded_at` - When the record was loaded into Snowflake

## Support

For support, please contact:

- Email: [support@getorchestra.io](mailto:support@getorchestra.io)
- Documentation: [https://docs.getorchestra.io/docs/metadata-api/overview](https://docs.getorchestra.io/docs/metadata-api/overview)
