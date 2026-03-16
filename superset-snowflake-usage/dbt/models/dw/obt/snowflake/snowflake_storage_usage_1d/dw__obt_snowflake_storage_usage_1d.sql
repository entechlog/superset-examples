{{ config(
    alias = 'snowflake_storage_usage_1d',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date_id', 'database_name', 'unit'],
    on_schema_change = 'sync_all_columns',
    cluster_by = ['date', 'database_name', 'unit'],
    tags = ['dw', 'obt'],
    pre_hook = "{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

WITH base_storage AS (
    SELECT
        sf.date_id,
        sf.DATABASE_NAME,
        sf.ENVIRONMENT,
        -- Raw storage metrics in BYTES (source of truth)
        sf.STORAGE_BYTES,
        sf.STAGE_BYTES,
        sf.FAILSAFE_BYTES,
        COALESCE(sf.HYBRID_TABLE_STORAGE_BYTES, 0) AS HYBRID_TABLE_BYTES,
        sf.TOTAL_STORAGE_BYTES,
        
        -- Cost and other metrics (same for all units)
        CASE 
            WHEN sf.ESTIMATED_DAILY_COST_USD < 0.01 THEN 0
            ELSE ROUND(sf.ESTIMATED_DAILY_COST_USD, 2)
        END AS estimated_daily_cost_usd,
        
        -- Storage breakdown percentages (using bytes for accuracy)
        CASE 
            WHEN sf.TOTAL_STORAGE_BYTES > 0 THEN 
                ROUND((sf.STORAGE_BYTES::FLOAT / sf.TOTAL_STORAGE_BYTES) * 100, 2)
            ELSE 0 
        END AS storage_percentage,
        
        CASE 
            WHEN sf.TOTAL_STORAGE_BYTES > 0 THEN 
                ROUND((sf.STAGE_BYTES::FLOAT / sf.TOTAL_STORAGE_BYTES) * 100, 2)
            ELSE 0 
        END AS stage_percentage,
        
        CASE 
            WHEN sf.TOTAL_STORAGE_BYTES > 0 THEN 
                ROUND((sf.FAILSAFE_BYTES::FLOAT / sf.TOTAL_STORAGE_BYTES) * 100, 2)
            ELSE 0 
        END AS failsafe_percentage,
        
        CASE 
            WHEN sf.TOTAL_STORAGE_BYTES > 0 THEN 
                ROUND((COALESCE(sf.HYBRID_TABLE_STORAGE_BYTES, 0)::FLOAT / sf.TOTAL_STORAGE_BYTES) * 100, 2)
            ELSE 0 
        END AS hybrid_table_percentage,
        
        -- Storage tier
        {{ get_storage_tier('sf.TOTAL_STORAGE_BYTES') }} AS storage_tier

    FROM {{ ref('dw__fact_snowflake_storage_usage') }} sf
    
    {% if is_incremental() %}
        WHERE sf.date_id = {{ var('batch_cycle_date') | replace('-', '') }}
    {% endif %}
),

-- Get all unique databases and their first appearance date
database_spine AS (
    SELECT 
        database_name,
        environment,
        MIN(date_id) AS min_date_id
    FROM base_storage
    GROUP BY database_name, environment
),

-- Create date spine from min date for each database to current date
date_spine AS (
    SELECT 
        ds.database_name,
        ds.environment,
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
    FROM database_spine ds
    CROSS JOIN {{ ref('dw__dim_date') }} d
    WHERE d.date_id >= ds.min_date_id
    {% if is_incremental() %}
        AND d.date_id = {{ var('batch_cycle_date') | replace('-', '') }}
    {% else %}
        AND d.date <= CURRENT_DATE()
    {% endif %}
),

-- Join spine with actual data, filling gaps with zeros
storage_with_spine AS (
    SELECT 
        sp.date_id,
        sp.database_name,
        sp.environment,
        -- Use actual data if available, otherwise zeros
        COALESCE(s.STORAGE_BYTES, 0) AS STORAGE_BYTES,
        COALESCE(s.STAGE_BYTES, 0) AS STAGE_BYTES,
        COALESCE(s.FAILSAFE_BYTES, 0) AS FAILSAFE_BYTES,
        COALESCE(s.HYBRID_TABLE_BYTES, 0) AS HYBRID_TABLE_BYTES,
        COALESCE(s.TOTAL_STORAGE_BYTES, 0) AS TOTAL_STORAGE_BYTES,
        
        -- For missing data, set cost and percentages to 0
        COALESCE(s.estimated_daily_cost_usd, 0) AS estimated_daily_cost_usd,
        COALESCE(s.storage_percentage, 0) AS storage_percentage,
        COALESCE(s.stage_percentage, 0) AS stage_percentage,
        COALESCE(s.failsafe_percentage, 0) AS failsafe_percentage,
        COALESCE(s.hybrid_table_percentage, 0) AS hybrid_table_percentage,
        COALESCE(s.storage_tier, 'UNKNOWN') AS storage_tier
    FROM date_spine sp
    LEFT JOIN base_storage s ON sp.date_id = s.date_id AND sp.database_name = s.database_name
),

-- Create one row per date per database per unit
storage_by_unit AS (
    -- BYTES unit
    SELECT 
        s.date_id,
        s.DATABASE_NAME,
        s.ENVIRONMENT,
        'BYTES' as unit,
        s.TOTAL_STORAGE_BYTES as total_storage,
        s.STORAGE_BYTES as table_storage,
        s.STAGE_BYTES as stage_storage,
        s.FAILSAFE_BYTES as failsafe_storage,
        s.HYBRID_TABLE_BYTES as hybrid_table_storage,
        -- Shared metrics
        s.estimated_daily_cost_usd,
        s.storage_percentage,
        s.stage_percentage,
        s.failsafe_percentage,
        s.hybrid_table_percentage,
        s.storage_tier
    FROM storage_with_spine s
    
    UNION ALL
    
    -- KB unit
    SELECT 
        s.date_id,
        s.DATABASE_NAME,
        s.ENVIRONMENT,
        'KB' as unit,
        ROUND(s.TOTAL_STORAGE_BYTES / POWER(1024, 1), 2) as total_storage,
        ROUND(s.STORAGE_BYTES / POWER(1024, 1), 2) as table_storage,
        ROUND(s.STAGE_BYTES / POWER(1024, 1), 2) as stage_storage,
        ROUND(s.FAILSAFE_BYTES / POWER(1024, 1), 2) as failsafe_storage,
        ROUND(s.HYBRID_TABLE_BYTES / POWER(1024, 1), 2) as hybrid_table_storage,
        s.estimated_daily_cost_usd,
        s.storage_percentage,
        s.stage_percentage,
        s.failsafe_percentage,
        s.hybrid_table_percentage,
        s.storage_tier
    FROM storage_with_spine s
    
    UNION ALL
    
    -- MB unit  
    SELECT 
        s.date_id,
        s.DATABASE_NAME,
        s.ENVIRONMENT,
        'MB' as unit,
        ROUND(s.TOTAL_STORAGE_BYTES / POWER(1024, 2), 2) as total_storage,
        ROUND(s.STORAGE_BYTES / POWER(1024, 2), 2) as table_storage,
        ROUND(s.STAGE_BYTES / POWER(1024, 2), 2) as stage_storage,
        ROUND(s.FAILSAFE_BYTES / POWER(1024, 2), 2) as failsafe_storage,
        ROUND(s.HYBRID_TABLE_BYTES / POWER(1024, 2), 2) as hybrid_table_storage,
        s.estimated_daily_cost_usd,
        s.storage_percentage,
        s.stage_percentage,
        s.failsafe_percentage,
        s.hybrid_table_percentage,
        s.storage_tier
    FROM storage_with_spine s
    
    UNION ALL
    
    -- GB unit
    SELECT 
        s.date_id,
        s.DATABASE_NAME,
        s.ENVIRONMENT,
        'GB' as unit,
        ROUND(s.TOTAL_STORAGE_BYTES / POWER(1024, 3), 3) as total_storage,
        ROUND(s.STORAGE_BYTES / POWER(1024, 3), 3) as table_storage,
        ROUND(s.STAGE_BYTES / POWER(1024, 3), 3) as stage_storage,
        ROUND(s.FAILSAFE_BYTES / POWER(1024, 3), 3) as failsafe_storage,
        ROUND(s.HYBRID_TABLE_BYTES / POWER(1024, 3), 3) as hybrid_table_storage,
        s.estimated_daily_cost_usd,
        s.storage_percentage,
        s.stage_percentage,
        s.failsafe_percentage,
        s.hybrid_table_percentage,
        s.storage_tier
    FROM storage_with_spine s
    
    UNION ALL
    
    -- TB unit (set to 0 for small storage to avoid scientific notation)
    SELECT 
        s.date_id,
        s.DATABASE_NAME,
        s.ENVIRONMENT,
        'TB' as unit,
        CASE WHEN s.TOTAL_STORAGE_BYTES >= POWER(1024, 3) * 100 
             THEN ROUND(s.TOTAL_STORAGE_BYTES / POWER(1024, 4), 6) 
             ELSE 0 END as total_storage,
        CASE WHEN s.STORAGE_BYTES >= POWER(1024, 3) * 100 
             THEN ROUND(s.STORAGE_BYTES / POWER(1024, 4), 6) 
             ELSE 0 END as table_storage,
        CASE WHEN s.STAGE_BYTES >= POWER(1024, 3) * 100 
             THEN ROUND(s.STAGE_BYTES / POWER(1024, 4), 6) 
             ELSE 0 END as stage_storage,
        CASE WHEN s.FAILSAFE_BYTES >= POWER(1024, 3) * 100 
             THEN ROUND(s.FAILSAFE_BYTES / POWER(1024, 4), 6) 
             ELSE 0 END as failsafe_storage,
        CASE WHEN s.HYBRID_TABLE_BYTES >= POWER(1024, 3) * 100 
             THEN ROUND(s.HYBRID_TABLE_BYTES / POWER(1024, 4), 6) 
             ELSE 0 END as hybrid_table_storage,
        s.estimated_daily_cost_usd,
        s.storage_percentage,
        s.stage_percentage,
        s.failsafe_percentage,
        s.hybrid_table_percentage,
        s.storage_tier
    FROM storage_with_spine s
),

-- Add date dimension and growth calculations
final_with_growth AS (
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
        
        u.database_name,
        u.environment,
        u.unit,
        u.total_storage,
        u.table_storage,
        u.stage_storage,
        u.failsafe_storage,
        u.hybrid_table_storage,
        
        -- Shared metrics (same for all units)
        u.estimated_daily_cost_usd,
        u.storage_percentage,
        u.stage_percentage,
        u.failsafe_percentage,
        u.hybrid_table_percentage,
        u.storage_tier,
        
        -- Growth calculations (day-over-day for same unit, database, and environment)
        LAG(u.total_storage, 1) OVER (
            PARTITION BY u.unit, u.database_name, u.environment 
            ORDER BY d.date
        ) AS prev_day_total_storage,
        
        CASE 
            WHEN LAG(u.total_storage, 1) OVER (PARTITION BY u.unit, u.database_name, u.environment ORDER BY d.date) > 0 THEN 
                ROUND(((u.total_storage - LAG(u.total_storage, 1) OVER (PARTITION BY u.unit, u.database_name, u.environment ORDER BY d.date)) / 
                       LAG(u.total_storage, 1) OVER (PARTITION BY u.unit, u.database_name, u.environment ORDER BY d.date)) * 100, 4)
            ELSE 0
        END AS total_storage_growth_pct_daily,
        
        ROUND(u.total_storage - LAG(u.total_storage, 1) OVER (PARTITION BY u.unit, u.database_name, u.environment ORDER BY d.date), 3) AS total_storage_growth_daily,
        
        -- Environment classification for cost allocation (matching warehouse model)
        CASE 
            WHEN u.environment = 'PRD' THEN u.estimated_daily_cost_usd
            ELSE 0 
        END AS production_cost_usd,
        
        CASE 
            WHEN u.environment IN ('DEV', 'TEST') THEN u.estimated_daily_cost_usd
            ELSE 0 
        END AS development_cost_usd,
        
        CASE 
            WHEN u.environment = 'STG' THEN u.estimated_daily_cost_usd
            ELSE 0 
        END AS staging_cost_usd
        
    FROM storage_by_unit u
    JOIN {{ ref('dw__dim_date') }} d ON d.date_id = u.date_id
)

SELECT * FROM final_with_growth
ORDER BY date, environment, database_name, unit