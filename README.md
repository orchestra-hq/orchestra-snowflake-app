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
4. **Configuration Management**: Handles API key security through parameters

## Key Features

- **Pipeline Runs**: Fetch pipeline execution data and performance metrics
- **Task Runs**: Access detailed task execution information
- **Operations**: Retrieve operations metadata and status
- **Secure API Key Handling**: API keys passed as parameters (not stored in the app)
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
-- Test the connection with your API key
SELECT core.get_pipeline_runs('your-api-key', 5);
```

### 2. Create Data Tables

```sql
-- Create a table for pipeline runs
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
```

### 3. Load Data

```sql
-- Load pipeline runs data
CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');
```

## Usage Examples

### Fetch Data Directly

```sql
-- Get recent pipeline runs
SELECT core.get_pipeline_runs('your-api-key', 100);

-- Get task runs
SELECT core.get_task_runs('your-api-key', 50);

-- Get operations
SELECT core.get_operations('your-api-key', 25);
```

### Load Data into Tables

```sql
-- Load pipeline runs to a table
CALL core.load_pipeline_runs_to_table('your-api-key', 'pipeline_runs');

-- Load task runs to a table
CALL core.load_task_runs_to_table('your-api-key', 'task_runs');

-- Load operations to a table
CALL core.load_operations_to_table('your-api-key', 'operations');
```

### Extract Specific Data

```sql
-- Extract pipeline run details
SELECT
    value:id::STRING as pipeline_run_id,
    value:pipeline_id::STRING as pipeline_id,
    value:status::STRING as status,
    value:started_at::TIMESTAMP_NTZ as started_at,
    value:completed_at::TIMESTAMP_NTZ as completed_at
FROM TABLE(FLATTEN(input => core.get_pipeline_runs('your-api-key'):pipeline_runs));
```

## Available Procedures

### Data Fetching

- `core.get_pipeline_runs(api_key, limit)` - Fetch pipeline runs
- `core.get_task_runs(api_key, limit)` - Fetch task runs
- `core.get_operations(api_key, limit)` - Fetch operations

### Data Loading

- `core.load_pipeline_runs_to_table(api_key, target_table)` - Load pipeline runs to a table
- `core.load_task_runs_to_table(api_key, target_table)` - Load task runs to a table
- `core.load_operations_to_table(api_key, target_table)` - Load operations to a table

### Setup

- `core.create_eai_objects()` - Create EAI objects and procedures

## Security

- **API Key Security**: Keys are passed as parameters, not stored in the app
- **Network Security**: Access restricted to `app.getorchestra.io` through EAI
- **HTTPS Only**: All API calls use secure connections
- **Error Handling**: Proper error handling prevents data leakage
- **Audit Trail**: All API calls are logged for audit purposes

## Documentation

- [Setup Guide](docs/setup-guide.md) - Complete setup instructions
- [API Reference](docs/api-reference.md) - Available procedures and parameters
- [Examples](docs/examples.md) - Common use cases and examples
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## Development

### Project Structure

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
├── scripts/
│   ├── quick_start.sql        # Quick setup script
│   ├── setup_orchestra_integration.sql  # Complete setup
│   └── example_queries.sql    # Example analysis queries
└── docs/
    ├── setup-guide.md         # Setup instructions
    ├── api-reference.md       # API documentation
    ├── examples.md            # Usage examples
    └── troubleshooting.md     # Troubleshooting guide
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
