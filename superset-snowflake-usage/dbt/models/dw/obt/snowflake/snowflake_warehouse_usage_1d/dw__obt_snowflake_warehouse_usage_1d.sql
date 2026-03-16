{{ config(
    alias = 'snowflake_warehouse_usage_1d',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date_id', 'warehouse_name'],
    on_schema_change = 'sync_all_columns',
    cluster_by = ['date', 'environment'],
    tags = ['dw', 'obt'],
    pre_hook = "{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

WITH daily_warehouse_usage AS (
    SELECT
        date_id,
        warehouse_name,
        environment,
        -- Usage metrics (rounded to avoid scientific notation)
        COUNT(*) AS usage_sessions,
        ROUND(SUM(credits_used), 6) AS total_credits_used,
        ROUND(SUM(credits_used_compute), 6) AS total_credits_compute,
        ROUND(SUM(credits_used_cloud_services), 6) AS total_credits_cloud_services,
        ROUND(SUM(estimated_cost_usd), 2) AS total_cost_usd,
        
        -- Time-based metrics
        MIN(start_time) AS first_usage_time,
        MAX(end_time) AS last_usage_time,
        COUNT(DISTINCT usage_hour) AS active_hours,
        
        -- Performance metrics (rounded to avoid scientific notation)
        ROUND(AVG(credits_used), 6) AS avg_credits_per_session,
        ROUND(MAX(credits_used), 6) AS max_credits_per_session,
        ROUND(MIN(credits_used), 6) AS min_credits_per_session,
        
        -- Activity flags
        CASE WHEN SUM(credits_used) > 0 THEN 1 ELSE 0 END AS is_active_warehouse,
        CASE WHEN SUM(credits_used_compute) > 0 THEN 1 ELSE 0 END AS has_compute_usage,
        CASE WHEN SUM(credits_used_cloud_services) > 0 THEN 1 ELSE 0 END AS has_cloud_services_usage,
        
        -- Usage pattern analysis
        {{ get_utilization_pattern('COUNT(DISTINCT usage_hour)') }} AS utilization_pattern,
        
        -- Keep warehouse_id as informational (use latest one for the name)
        MAX(warehouse_id) AS warehouse_id_latest
        
    FROM {{ ref('dw__fact_snowflake_warehouse_usage') }}
    
    {% if is_incremental() %}
        WHERE date_id = {{ var('batch_cycle_date') | replace('-', '') }}
    {% endif %}
    
    -- Group by name only, not ID
    GROUP BY date_id, warehouse_name, environment
),

-- Get all unique warehouses and their first appearance date
warehouse_spine AS (
    SELECT 
        warehouse_name,
        environment,
        MIN(date_id) AS min_date_id
    FROM daily_warehouse_usage
    GROUP BY warehouse_name, environment
),

-- Create date spine from min date for each warehouse to current date
date_spine AS (
    SELECT 
        ws.warehouse_name,
        ws.environment,
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
warehouse_with_spine AS (
    SELECT 
        sp.date_id,
        sp.warehouse_name,
        sp.environment,
        
        -- Usage metrics (use actual data if available, otherwise zeros)
        COALESCE(w.usage_sessions, 0) AS usage_sessions,
        COALESCE(w.total_credits_used, 0) AS total_credits_used,
        COALESCE(w.total_credits_compute, 0) AS total_credits_compute,
        COALESCE(w.total_credits_cloud_services, 0) AS total_credits_cloud_services,
        COALESCE(w.total_cost_usd, 0) AS total_cost_usd,
        
        -- Time-based metrics (null for no usage days)
        w.first_usage_time,
        w.last_usage_time,
        COALESCE(w.active_hours, 0) AS active_hours,
        
        -- Performance metrics (zeros for no usage days)
        COALESCE(w.avg_credits_per_session, 0) AS avg_credits_per_session,
        COALESCE(w.max_credits_per_session, 0) AS max_credits_per_session,
        COALESCE(w.min_credits_per_session, 0) AS min_credits_per_session,
        
        -- Activity flags (false for no usage days)
        COALESCE(w.is_active_warehouse, 0) AS is_active_warehouse,
        COALESCE(w.has_compute_usage, 0) AS has_compute_usage,
        COALESCE(w.has_cloud_services_usage, 0) AS has_cloud_services_usage,
        
        -- Usage patterns (none for no usage days)
        COALESCE(w.utilization_pattern, 'None') AS utilization_pattern,
        
        -- Warehouse ID (informational only)
        w.warehouse_id_latest AS warehouse_id
        
    FROM date_spine sp
    LEFT JOIN daily_warehouse_usage w ON sp.date_id = w.date_id AND sp.warehouse_name = w.warehouse_name
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
    
    w.warehouse_name,
    w.warehouse_id,  -- Keep as informational
    w.environment,
    
    -- Usage metrics
    w.usage_sessions,
    w.total_credits_used,
    w.total_credits_compute,
    w.total_credits_cloud_services,
    w.total_cost_usd,
    
    -- Time-based metrics  
    w.first_usage_time,
    w.last_usage_time,
    w.active_hours,
    
    -- Performance metrics
    w.avg_credits_per_session,
    w.max_credits_per_session,
    w.min_credits_per_session,
    
    -- Activity flags
    w.is_active_warehouse,
    w.has_compute_usage,
    w.has_cloud_services_usage,
    
    -- Usage patterns
    w.utilization_pattern,
    
    -- Efficiency metrics (rounded to avoid scientific notation)
    CASE 
        WHEN w.total_credits_used > 0 THEN ROUND(w.total_cost_usd / w.total_credits_used, 4)
        ELSE 0 
    END AS cost_per_credit,
    
    CASE 
        WHEN w.active_hours > 0 THEN ROUND(w.total_credits_used / w.active_hours, 6)
        ELSE 0 
    END AS credits_per_active_hour,
    
    -- Environment classification for cost allocation (rounded)
    CASE 
        WHEN w.environment = 'PRD' THEN ROUND(w.total_cost_usd, 2)
        ELSE 0 
    END AS production_cost_usd,
    
    CASE 
        WHEN w.environment IN ('DEV', 'TEST') THEN ROUND(w.total_cost_usd, 2)
        ELSE 0 
    END AS development_cost_usd,
    
    CASE 
        WHEN w.environment = 'STG' THEN ROUND(w.total_cost_usd, 2)
        ELSE 0 
    END AS staging_cost_usd

FROM warehouse_with_spine w
JOIN {{ ref('dw__dim_date') }} d ON d.date_id = w.date_id
ORDER BY d.date, w.environment, w.warehouse_name