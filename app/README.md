# Orchestra Data App

This Snowflake Native Application allows you to pull data from the Orchestra API directly into Snowflake using External Access Integration (EAI).

## Features

- **Metadata**: Fetch pipeline runs, task runs and operations metadata directly from the Orchestra API
- **Secure**: API keys are handled securely through Snowflake secrets
- **Easy to Use**: Simple stored procedures for data access

## Prerequisites

### Required Database and Schema

**IMPORTANT**: Before installing this app, you must create the following database and schema:

```sql
-- Create the required database
CREATE DATABASE IF NOT EXISTS ORCHESTRA_DATA;

-- Create the required schema
CREATE SCHEMA IF NOT EXISTS ORCHESTRA_DATA.PUBLIC;
```

The app will automatically create tables in the `ORCHESTRA_DATA.PUBLIC` schema when you run the setup procedures.

### Other Prerequisites

- Snowflake account with appropriate privileges
- Orchestra API key from [https://app.getorchestra.io/settings/api-key](https://app.getorchestra.io/settings/api-key)

## Getting Started

### Installation

1. Install the app from the Snowflake Marketplace
2. Grant the External Access Integration reference when prompted
3. Run the setup procedure to create the API access objects

### Setup

After installation, run the following to create the API access objects and tables:

```sql
-- Create the EAI objects (run this after granting the reference)
CALL core.create_eai_objects();

-- Create the output tables in ORCHESTRA_DATA.PUBLIC schema
CALL core.create_output_tables();
```

**Note**: The `create_output_tables()` procedure will validate that the `ORCHESTRA_DATA` database and `PUBLIC` schema exist before creating tables. If they don't exist, you'll get a clear error message.

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

The app automatically creates the following tables in the `ORCHESTRA_DATA.PUBLIC` schema:

- `pipeline_runs` - Stores pipeline run metadata
- `task_runs` - Stores task run metadata
- `operations` - Stores operation metadata

To load data into these tables:

```sql
-- Load pipeline runs data
CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');
CALL core.load_task_runs_to_table('your-api-key', 'task_runs');
CALL core.load_operations_to_table('your-api-key', 'operations');
```

**Note**: The table names should be just the table name (e.g., 'pipeline_runs'), not the full qualified name, as the procedures automatically target the `ORCHESTRA_DATA.PUBLIC` schema.

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
