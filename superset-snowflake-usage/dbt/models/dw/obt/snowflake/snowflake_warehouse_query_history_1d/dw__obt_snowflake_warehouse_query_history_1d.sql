{{ config(
    alias = 'snowflake_warehouse_query_history_1d',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date_id', 'warehouse_name'],
    on_schema_change = 'sync_all_columns',
    cluster_by = ['date_id', 'warehouse_environment'],
    tags = ['dw', 'obt'],
    pre_hook = "{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

WITH daily_query_warehouse AS (
    SELECT
        q.date_id,
        q.WAREHOUSE_NAME,
        q.WAREHOUSE_ENVIRONMENT,
        
        -- Query count metrics
        COUNT(*) AS total_queries,
        SUM(q.IS_SUCCESSFUL) AS successful_queries,
        SUM(q.IS_FAILED) AS failed_queries,
        SUM(q.IS_SLOW_QUERY) AS slow_queries,
        SUM(q.IS_VERY_SLOW_QUERY) AS very_slow_queries,
        SUM(q.IS_LARGE_SCAN) AS large_scan_queries,
        SUM(q.HAS_SPILLING) AS spilling_queries,
        
        -- Performance metrics (rounded)
        ROUND(AVG(q.EXECUTION_TIME_SECONDS), 4) AS avg_execution_time_seconds,
        ROUND(MAX(q.EXECUTION_TIME_SECONDS), 4) AS max_execution_time_seconds,
        ROUND(MIN(q.EXECUTION_TIME_SECONDS), 4) AS min_execution_time_seconds,
        ROUND(AVG(q.COMPILATION_TIME_SECONDS), 4) AS avg_compilation_time_seconds,
        ROUND(AVG(q.QUEUED_TIME_SECONDS), 4) AS avg_queued_time_seconds,
        
        -- Resource usage metrics (rounded)
        ROUND(SUM(q.CREDITS_USED_CLOUD_SERVICES), 6) AS total_credits_cloud_services,
        ROUND(SUM(q.BYTES_SCANNED), 0) AS total_bytes_scanned,
        ROUND(SUM(q.BYTES_WRITTEN), 0) AS total_bytes_written,
        ROUND(SUM(q.ROWS_PRODUCED), 0) AS total_rows_produced,
        
        -- Cost metrics (rounded)
        ROUND(SUM(q.ESTIMATED_QUERY_COST_USD), 4) AS total_estimated_cost_usd,
        ROUND(AVG(q.ESTIMATED_QUERY_COST_USD), 6) AS avg_estimated_cost_usd,
        
        -- Performance ratios
        CASE 
            WHEN COUNT(*) > 0 THEN ROUND((SUM(q.IS_SUCCESSFUL)::FLOAT / COUNT(*)) * 100, 2)
            ELSE 0 
        END AS success_rate_pct,
        
        CASE 
            WHEN COUNT(*) > 0 THEN ROUND((SUM(q.IS_SLOW_QUERY)::FLOAT / COUNT(*)) * 100, 2)
            ELSE 0 
        END AS slow_query_rate_pct,
        
        -- User and database diversity metrics
        COUNT(DISTINCT q.USER_NAME) AS unique_users,
        COUNT(DISTINCT q.DATABASE_NAME) AS unique_databases,
        COUNT(DISTINCT q.SCHEMA_NAME) AS unique_schemas,
        
        -- Keep warehouse_id as informational (use latest one for the name)
        MAX(q.WAREHOUSE_ID) AS warehouse_id_latest
        
    FROM {{ ref('dw__fact_snowflake_query_history') }} q
    
    {% if is_incremental() %}
        WHERE q.date_id = {{ var('batch_cycle_date') | replace('-', '') }}
    {% endif %}
    
    -- Group by name only, not ID
    GROUP BY q.date_id, q.WAREHOUSE_NAME, q.WAREHOUSE_ENVIRONMENT
),

-- Get all unique warehouses and their first appearance date
warehouse_spine AS (
    SELECT 
        warehouse_name,
        warehouse_environment,
        MIN(date_id) AS min_date_id
    FROM daily_query_warehouse
    GROUP BY warehouse_name, warehouse_environment
),

-- Create date spine from min date for each warehouse to current date
date_spine AS (
    SELECT 
        ws.warehouse_name,
        ws.warehouse_environment,
        d.date_id,
        d.date,
        d.year,
        d.month,
        d.day,
        d.day_of_week,
        d.is_weekend,
        d.month_name,
        d.quarter,
        d.week_of_year
    FROM warehouse_spine ws
    CROSS JOIN {{ ref('dw__dim_date') }} d
    WHERE d.date_id >= ws.min_date_id
    {% if is_incremental() %}
        AND d.date_id = {{ var('batch_cycle_date') | replace('-', '') }}
    {% else %}
        AND d.date <= CURRENT_DATE()
    {% endif %}
),

-- Join spine with actual data, filling gaps with zeros
query_with_spine AS (
    SELECT 
        sp.date_id,
        sp.warehouse_name,
        sp.warehouse_environment,
        
        -- Query count metrics (use actual data if available, otherwise zeros)
        COALESCE(q.total_queries, 0) AS total_queries,
        COALESCE(q.successful_queries, 0) AS successful_queries,
        COALESCE(q.failed_queries, 0) AS failed_queries,
        COALESCE(q.slow_queries, 0) AS slow_queries,
        COALESCE(q.very_slow_queries, 0) AS very_slow_queries,
        COALESCE(q.large_scan_queries, 0) AS large_scan_queries,
        COALESCE(q.spilling_queries, 0) AS spilling_queries,
        
        -- Performance metrics (zeros for no query days)
        COALESCE(q.avg_execution_time_seconds, 0) AS avg_execution_time_seconds,
        COALESCE(q.max_execution_time_seconds, 0) AS max_execution_time_seconds,
        COALESCE(q.min_execution_time_seconds, 0) AS min_execution_time_seconds,
        COALESCE(q.avg_compilation_time_seconds, 0) AS avg_compilation_time_seconds,
        COALESCE(q.avg_queued_time_seconds, 0) AS avg_queued_time_seconds,
        
        -- Resource usage metrics (zeros for no query days)
        COALESCE(q.total_credits_cloud_services, 0) AS total_credits_cloud_services,
        COALESCE(q.total_bytes_scanned, 0) AS total_bytes_scanned,
        COALESCE(q.total_bytes_written, 0) AS total_bytes_written,
        COALESCE(q.total_rows_produced, 0) AS total_rows_produced,
        
        -- Cost metrics (zeros for no query days)
        COALESCE(q.total_estimated_cost_usd, 0) AS total_estimated_cost_usd,
        COALESCE(q.avg_estimated_cost_usd, 0) AS avg_estimated_cost_usd,
        
        -- Performance ratios (zeros for no query days)
        COALESCE(q.success_rate_pct, 0) AS success_rate_pct,
        COALESCE(q.slow_query_rate_pct, 0) AS slow_query_rate_pct,
        
        -- User and database diversity metrics (zeros for no query days)
        COALESCE(q.unique_users, 0) AS unique_users,
        COALESCE(q.unique_databases, 0) AS unique_databases,
        COALESCE(q.unique_schemas, 0) AS unique_schemas,
        
        -- Warehouse ID (informational only)
        q.warehouse_id_latest AS warehouse_id
        
    FROM date_spine sp
    LEFT JOIN daily_query_warehouse q ON sp.date_id = q.date_id 
        AND sp.warehouse_name = q.warehouse_name
)

SELECT 
    d.date_id,
    d.date,
    d.year,
    d.month,
    d.day,
    d.day_of_week,
    d.is_weekend,
    d.month_name,
    d.quarter,
    d.week_of_year,
    
    q.warehouse_name,
    q.warehouse_id,  -- Keep as informational
    q.warehouse_environment,
    
    -- Query count metrics
    q.total_queries,
    q.successful_queries,
    q.failed_queries,
    q.slow_queries,
    q.very_slow_queries,
    q.large_scan_queries,
    q.spilling_queries,
    
    -- Performance metrics
    q.avg_execution_time_seconds,
    q.max_execution_time_seconds,
    q.min_execution_time_seconds,
    q.avg_compilation_time_seconds,
    q.avg_queued_time_seconds,
    
    -- Resource usage metrics
    q.total_credits_cloud_services,
    q.total_bytes_scanned,
    q.total_bytes_written,
    q.total_rows_produced,
    
    -- Cost metrics
    q.total_estimated_cost_usd,
    q.avg_estimated_cost_usd,
    
    -- Performance ratios
    q.success_rate_pct,
    q.slow_query_rate_pct,
    
    -- User and database diversity metrics
    q.unique_users,
    q.unique_databases,
    q.unique_schemas,
    
    -- Activity flags
    CASE WHEN q.total_queries > 0 THEN 1 ELSE 0 END AS is_active_warehouse,
    CASE WHEN q.failed_queries > 0 THEN 1 ELSE 0 END AS has_failed_queries,
    CASE WHEN q.slow_queries > 0 THEN 1 ELSE 0 END AS has_slow_queries,
    
    -- Environment classification for cost allocation
    CASE 
        WHEN q.warehouse_environment = 'PRD' THEN q.total_estimated_cost_usd
        ELSE 0 
    END AS production_cost_usd,
    
    CASE 
        WHEN q.warehouse_environment IN ('DEV', 'TEST') THEN q.total_estimated_cost_usd
        ELSE 0 
    END AS development_cost_usd,
    
    CASE 
        WHEN q.warehouse_environment = 'STG' THEN q.total_estimated_cost_usd
        ELSE 0 
    END AS staging_cost_usd

FROM query_with_spine q
JOIN {{ ref('dw__dim_date') }} d ON d.date_id = q.date_id
ORDER BY d.date, q.warehouse_environment, q.warehouse_name