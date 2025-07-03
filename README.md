# Orchestra Data App

A Snowflake Native Application that provides seamless integration with the Orchestra API to fetch and store pipeline runs, task runs, and operations metadata directly in Snowflake using External Access Integration (EAI).

## Overview

The Orchestra Data App allows you to:

- **Fetch Orchestra API data** directly into Snowflake without manual external function setup
- **Store pipeline runs, task runs, and operations** in Snowflake tables for analysis and reporting
- **Automate data synchronization** through scheduled tasks and helper procedures
- **Secure API access** using Snowflake's External Access Integration feature

## Architecture

The app uses Snowflake's External Access Integration (EAI) to provide a seamless customer experience:

1. **External Access Integration (EAI)**: Handles secure network access to `app.getorchestra.io`
2. **Python Stored Procedures**: Make API calls to Orchestra endpoints using EAI references
3. **Helper Procedures**: Simplify data loading and processing into tables
4. **Configuration Management**: Handles API key security through Snowflake secrets

## Key Features

- **Pipeline Runs**: Fetch pipeline execution data and performance metrics
- **Task Runs**: Access detailed task execution information
- **Operations**: Retrieve operations metadata and status
- **Secure API Key Handling**: API keys managed through Snowflake secrets
- **Error Handling**: Comprehensive error handling for API failures
- **Easy Data Loading**: Helper procedures for loading data into tables
- **Automation Ready**: Built-in support for scheduled data refresh

## Installation

### Prerequisites

- Snowflake account with appropriate privileges
- Orchestra API key from [https://app.getorchestra.io/settings/api-key](https://app.getorchestra.io/settings/api-key)

### Steps

1. **Install the App**: Install from Snowflake Marketplace
2. **Grant EAI Reference**: Grant the External Access Integration reference when prompted
3. **Create Objects**: Run the setup procedure to create API access objects

```sql
-- After granting the EAI reference, create the API objects
CALL core.create_eai_objects();
```

## Quick Start

### 1. Test API Connection

```sql
-- Test the connection (API key is handled via secrets)
SELECT core.get_pipeline_runs();
```

### 2. Load Data into Tables

The app automatically creates tables in the `<APP_NAME>.PUBLIC` schema. Load data using the built-in procedures:

```sql
-- Load pipeline runs data
CALL core.load_pipeline_runs();

-- Load task runs data
CALL core.load_task_runs();

-- Load operations data
CALL core.load_operations();
```

## Usage Examples

### Fetch Data Directly

```sql
-- Get recent pipeline runs (defaults to page 1, 100 results per page)
SELECT core.get_pipeline_runs();

-- Get task runs with custom pagination
SELECT core.get_task_runs(2, 50);  -- page 2, 50 results per page

-- Get operations
SELECT core.get_operations();
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

### Extract Specific Data

```sql
-- Extract pipeline run details
SELECT
    value:id::STRING as pipeline_run_id,
    value:pipelineId::STRING as pipeline_id,
    value:runStatus::STRING as status,
    value:startedAt::TIMESTAMP_NTZ as started_at,
    value:completedAt::TIMESTAMP_NTZ as completed_at
FROM TABLE(FLATTEN(input => core.get_pipeline_runs():results));
```

## Available Procedures

### Data Fetching

- `core.get_pipeline_runs(page, per_page)` - Fetch pipeline runs (defaults: page=1, per_page=100)
- `core.get_task_runs(page, per_page)` - Fetch task runs (defaults: page=1, per_page=100)
- `core.get_operations(page, per_page)` - Fetch operations (defaults: page=1, per_page=100)

### Data Loading

- `core.load_pipeline_runs()` - Load pipeline runs to the public.pipeline_runs table
- `core.load_task_runs()` - Load task runs to the public.task_runs table
- `core.load_operations()` - Load operations to the public.operations table

### Setup

- `core.create_eai_objects()` - Create EAI objects and procedures

## Table Schemas

The app automatically creates three tables in the `public` schema:

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

## Security

- **API Key Security**: Keys are managed securely through Snowflake secrets
- **Network Security**: Access restricted to `app.getorchestra.io` through EAI
- **HTTPS Only**: All API calls use secure connections
- **Error Handling**: Proper error handling prevents data leakage
- **External Access Integration**: Ensures secure external API access

## Project Structure

```bash
orchestra-snowflake-app/
├── snowflake.yml              # App configuration
├── app/
│   ├── manifest.yml           # App manifest with EAI reference
│   ├── setup_script.sql       # Setup script with procedures
│   └── README.md              # App documentation
├── src/
│   └── module-api/
│       └── src/
│           └── orchestra.py   # Python API client
└── config/
    └── template.sql           # SQL template
```

### Building the App

```bash
# Build and deploy the app
snow app run
```

## Support

For support and documentation:

- **Email**: [support@getorchestra.io](mailto:support@getorchestra.io)
- **Documentation**: [https://docs.getorchestra.io](https://docs.getorchestra.io)
- **API Reference**: [https://docs.getorchestra.io/docs/metadata-api/](https://docs.getorchestra.io/docs/metadata-api/)

## License

This project is proprietary to Orchestra.
