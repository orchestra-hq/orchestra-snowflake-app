-- =====================================================
-- Orchestra Data App - Example Queries
-- =====================================================
-- This script contains example queries to help you analyze
-- your Orchestra data after setting up the app.
--
-- Prerequisites:
-- 1. Orchestra Data App installed and configured
-- 2. Data loaded into your tables
-- 3. Replace 'your-orchestra-api-key-here' with your actual API key
-- =====================================================

-- Set context
USE DATABASE ORCHESTRA_DATA;
USE SCHEMA METADATA;

-- =====================================================
-- Pipeline Runs Analysis
-- =====================================================

-- 1. Recent pipeline runs with status
SELECT 
    id,
    pipeline_id,
    pipeline_name,
    run_status,
    started_at,
    completed_at,
    DATEDIFF('minute', started_at, completed_at) as duration_minutes
FROM pipeline_runs 
WHERE started_at >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY started_at DESC;

-- 2. Pipeline performance summary
SELECT 
    pipeline_id,
    pipeline_name,
    COUNT(*) as total_runs,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes,
    SUM(CASE WHEN run_status = 'SUCCEEDED' THEN 1 ELSE 0 END) as successful_runs,
    SUM(CASE WHEN run_status = 'FAILED' THEN 1 ELSE 0 END) as failed_runs,
    SUM(CASE WHEN run_status = 'RUNNING' THEN 1 ELSE 0 END) as running_runs
FROM pipeline_runs 
GROUP BY pipeline_id, pipeline_name
ORDER BY total_runs DESC;

-- 3. Failed pipeline runs in the last 24 hours
SELECT 
    id,
    pipeline_id,
    pipeline_name,
    run_status,
    started_at,
    completed_at,
    message
FROM pipeline_runs 
WHERE run_status = 'FAILED' 
  AND started_at >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY started_at DESC;

-- =====================================================
-- Task Runs Analysis
-- =====================================================

-- 4. Recent task runs (if you have task_runs table)
-- Uncomment and run if you have loaded task runs data
/*
SELECT 
    id,
    pipeline_run_id,
    task_name,
    task_id,
    status,
    started_at,
    completed_at,
    DATEDIFF('second', started_at, completed_at) as duration_seconds
FROM task_runs 
WHERE started_at >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY started_at DESC;
*/

-- 5. Task performance summary
-- Uncomment and run if you have loaded task runs data
/*
SELECT 
    task_id,
    task_name,
    COUNT(*) as total_runs,
    AVG(DATEDIFF('second', started_at, completed_at)) as avg_duration_seconds,
    SUM(CASE WHEN status = 'SUCCEEDED' THEN 1 ELSE 0 END) as successful_runs,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_runs
FROM task_runs 
GROUP BY task_id, task_name
ORDER BY total_runs DESC;
*/

-- =====================================================
-- Operations Analysis
-- =====================================================

-- 6. Recent operations (if you have operations table)
-- Uncomment and run if you have loaded operations data
/*
SELECT 
    id,
    operation_name,
    operation_type,
    operation_status,
    started_at,
    completed_at,
    DATEDIFF('minute', started_at, completed_at) as duration_minutes
FROM operations 
WHERE started_at >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY started_at DESC;
*/

-- 7. Operations by type
-- Uncomment and run if you have loaded operations data
/*
SELECT 
    operation_type,
    COUNT(*) as total_operations,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes,
    SUM(CASE WHEN operation_status = 'SUCCEEDED' THEN 1 ELSE 0 END) as successful_ops,
    SUM(CASE WHEN operation_status = 'FAILED' THEN 1 ELSE 0 END) as failed_ops
FROM operations 
GROUP BY operation_type
ORDER BY total_operations DESC;
*/

-- =====================================================
-- Real-time Data Loading Examples
-- =====================================================

-- 8. Load fresh pipeline runs data
-- Replace 'your-orchestra-api-key-here' with your actual API key
-- CALL core.load_pipeline_runs_to_table('your-orchestra-api-key-here', 'ORCHESTRA_DATA.METADATA.pipeline_runs');

-- 9. Get latest pipeline runs without storing
-- Replace 'your-orchestra-api-key-here' with your actual API key
-- SELECT core.get_pipeline_runs('your-orchestra-api-key-here', 10) as latest_pipeline_runs;

-- 10. Get latest task runs without storing
-- Replace 'your-orchestra-api-key-here' with your actual API key
-- SELECT core.get_task_runs('your-orchestra-api-key-here', 10) as latest_task_runs;

-- 11. Get latest operations without storing
-- Replace 'your-orchestra-api-key-here' with your actual API key
-- SELECT core.get_operations('your-orchestra-api-key-here', 10) as latest_operations;

-- =====================================================
-- Data Quality Checks
-- =====================================================

-- 12. Check for missing data
SELECT 
    'pipeline_runs' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN id IS NULL THEN 1 END) as null_ids,
    COUNT(CASE WHEN run_status IS NULL THEN 1 END) as null_statuses,
    COUNT(CASE WHEN started_at IS NULL THEN 1 END) as null_started_at
FROM pipeline_runs
UNION ALL
-- Uncomment if you have task_runs table
/*
SELECT 
    'task_runs' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN id IS NULL THEN 1 END) as null_ids,
    COUNT(CASE WHEN status IS NULL THEN 1 END) as null_statuses,
    COUNT(CASE WHEN started_at IS NULL THEN 1 END) as null_started_at
FROM task_runs
UNION ALL
*/
-- Uncomment if you have operations table
/*
SELECT 
    'operations' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN id IS NULL THEN 1 END) as null_ids,
    COUNT(CASE WHEN operation_status IS NULL THEN 1 END) as null_statuses,
    COUNT(CASE WHEN started_at IS NULL THEN 1 END) as null_started_at
FROM operations
*/;

-- 13. Data freshness check
SELECT 
    'pipeline_runs' as table_name,
    MAX(loaded_at) as last_loaded,
    DATEDIFF('minute', MAX(loaded_at), CURRENT_TIMESTAMP()) as minutes_since_last_load
FROM pipeline_runs
UNION ALL
-- Uncomment if you have task_runs table
/*
SELECT 
    'task_runs' as table_name,
    MAX(loaded_at) as last_loaded,
    DATEDIFF('minute', MAX(loaded_at), CURRENT_TIMESTAMP()) as minutes_since_last_load
FROM task_runs
UNION ALL
*/
-- Uncomment if you have operations table
/*
SELECT 
    'operations' as table_name,
    MAX(loaded_at) as last_loaded,
    DATEDIFF('minute', MAX(loaded_at), CURRENT_TIMESTAMP()) as minutes_since_last_load
FROM operations
*/;

-- =====================================================
-- Dashboard Queries
-- =====================================================

-- 14. Pipeline runs by hour (last 24 hours)
SELECT 
    DATE_TRUNC('hour', started_at) as hour_bucket,
    COUNT(*) as pipeline_runs,
    SUM(CASE WHEN run_status = 'SUCCEEDED' THEN 1 ELSE 0 END) as successful_runs,
    SUM(CASE WHEN run_status = 'FAILED' THEN 1 ELSE 0 END) as failed_runs,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes
FROM pipeline_runs 
WHERE started_at >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY hour_bucket
ORDER BY hour_bucket;

-- 15. Top pipelines by execution time
SELECT 
    pipeline_id,
    COUNT(*) as execution_count,
    AVG(DATEDIFF('minute', started_at, completed_at)) as avg_duration_minutes,
    MAX(DATEDIFF('minute', started_at, completed_at)) as max_duration_minutes,
    MIN(DATEDIFF('minute', started_at, completed_at)) as min_duration_minutes
FROM pipeline_runs 
WHERE run_status = 'SUCCEEDED'
GROUP BY pipeline_id
HAVING COUNT(*) >= 5
ORDER BY avg_duration_minutes DESC
LIMIT 10; 