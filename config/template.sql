-- =====================================================
-- Orchestra API Integration - Configuration Template
-- =====================================================
-- Copy this file to config/your_config.sql and customize
-- the values below for your environment.
-- =====================================================

-- Configuration Variables
-- Replace these values with your actual configuration

-- Your Orchestra API key (get this from https://api.getorchestra.io)
SET ORCHESTRA_API_KEY = 'your-orchestra-api-key-here';

-- Your Snowflake role name
SET SNOWFLAKE_ROLE = 'your_role_name';

-- Your Snowflake warehouse name
SET SNOWFLAKE_WAREHOUSE = 'COMPUTE_WH';

-- Your Snowflake database name for Orchestra data
SET ORCHESTRA_DATABASE = 'ORCHESTRA_DATA';

-- Your Snowflake schema name for Orchestra data
SET ORCHESTRA_SCHEMA = 'METADATA';

-- Refresh schedule for data (CRON format)
-- Default: Daily at 2 AM UTC
SET REFRESH_SCHEDULE = 'USING CRON 0 2 * * * UTC';

-- Cache expiration time in minutes
SET CACHE_EXPIRATION_MINUTES = 60;

-- Batch size for processing large datasets
SET BATCH_SIZE = 100;

-- Maximum retry attempts for API calls
SET MAX_RETRIES = 3;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Copy this file to config/your_config.sql
-- 2. Replace all placeholder values with your actual values
-- 3. Source this file before running setup scripts:
--    SOURCE config/your_config.sql;
-- 4. Use the variables in your setup scripts:
--    CREATE OR REPLACE SECRET orchestra_api_key
--    TYPE = GENERIC_STRING
--    SECRET_STRING = $ORCHESTRA_API_KEY;
-- ===================================================== 