{{ config(
    alias = 'snowflake_storage_usage',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date_id', 'database_name'],
    on_schema_change = 'sync_all_columns',
    cluster_by = ['date_id', 'environment'],
    tags = ['dw', 'fact'],
    pre_hook = "{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

SELECT 
    d.date_id,
    s.DATABASE_NAME,
    s.ENVIRONMENT,
    
    -- Raw storage metrics in BYTES (source of truth for maximum precision)
    s.STORAGE_BYTES,
    s.STAGE_BYTES,
    s.FAILSAFE_BYTES,
    s.HYBRID_TABLE_STORAGE_BYTES,
    s.TOTAL_STORAGE_BYTES,
    
    -- Pre-calculated common units for convenience (but bytes remain source of truth)
    s.STORAGE_GB,
    s.STAGE_GB,
    s.FAILSAFE_GB,
    s.HYBRID_TABLE_GB,
    s.TOTAL_STORAGE_GB,
    
    -- Cost metrics
    s.ESTIMATED_DAILY_COST_USD
    
FROM {{ ref('prep__fact_snowflake_storage_usage') }} s
JOIN {{ ref('dw__dim_date') }} d ON d.date = s.USAGE_DATE