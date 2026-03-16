{{ config(
    alias = 'snowflake_storage_usage',
    materialized = 'view',
    tags = ['prep', 'fact']
) }}

WITH database_storage AS (
    -- Database-level storage with accurate environment classification
    SELECT
        DATE(ds.USAGE_DATE) AS USAGE_DATE,
        ds.DATABASE_NAME,
        {{ get_environment_code('ds.DATABASE_NAME') }} AS ENVIRONMENT,
        ds.AVERAGE_DATABASE_BYTES AS STORAGE_BYTES,
        ds.AVERAGE_FAILSAFE_BYTES AS FAILSAFE_BYTES,
        COALESCE(ds.AVERAGE_HYBRID_TABLE_STORAGE_BYTES, 0) AS HYBRID_TABLE_STORAGE_BYTES
    FROM snowflake.account_usage.database_storage_usage_history ds
    {{ filter_data(
        src_column_key = 'DATE(ds.USAGE_DATE)',
        src_operator = '=',
        src_column_val = "'" ~ var('batch_cycle_date') ~ "'"
    ) }}
    AND ds.DELETED IS NULL
),

account_stage_storage AS (
    -- Account-level stage storage - keep as separate environment
    SELECT
        DATE(ss.USAGE_DATE) AS USAGE_DATE,
        'ACCOUNT_STAGES' AS DATABASE_NAME,
        'SHARED' AS ENVIRONMENT,  -- Clearly indicates this is shared/account-level
        0 AS STORAGE_BYTES,
        SUM(ss.AVERAGE_STAGE_BYTES) AS STAGE_BYTES,
        0 AS FAILSAFE_BYTES,
        0 AS HYBRID_TABLE_STORAGE_BYTES
    FROM snowflake.account_usage.stage_storage_usage_history ss
    {{ filter_data(
        src_column_key = 'DATE(ss.USAGE_DATE)',
        src_operator = '=',
        src_column_val = "'" ~ var('batch_cycle_date') ~ "'"
    ) }}
    GROUP BY USAGE_DATE
),

combined_storage AS (
    -- Database storage by actual environment
    SELECT 
        USAGE_DATE,
        DATABASE_NAME,
        ENVIRONMENT,
        STORAGE_BYTES,
        0 AS STAGE_BYTES,
        FAILSAFE_BYTES,
        HYBRID_TABLE_STORAGE_BYTES
    FROM database_storage
    
    UNION ALL
    
    -- Account-level stage storage as "SHARED"
    SELECT 
        USAGE_DATE,
        DATABASE_NAME,
        ENVIRONMENT,  -- 'SHARED'
        STORAGE_BYTES,  -- 0
        STAGE_BYTES,
        FAILSAFE_BYTES,  -- 0  
        HYBRID_TABLE_STORAGE_BYTES  -- 0
    FROM account_stage_storage
)

SELECT
    USAGE_DATE,
    DATABASE_NAME,
    ENVIRONMENT,
    
    -- Raw bytes (preserve original precision)
    STORAGE_BYTES,
    STAGE_BYTES,
    FAILSAFE_BYTES,
    HYBRID_TABLE_STORAGE_BYTES,
    (STORAGE_BYTES + STAGE_BYTES + FAILSAFE_BYTES + HYBRID_TABLE_STORAGE_BYTES) AS TOTAL_STORAGE_BYTES,
    
    -- Pre-calculated GB for convenience
    STORAGE_BYTES / POWER(1024, 3) AS STORAGE_GB,
    STAGE_BYTES / POWER(1024, 3) AS STAGE_GB,
    FAILSAFE_BYTES / POWER(1024, 3) AS FAILSAFE_GB,
    HYBRID_TABLE_STORAGE_BYTES / POWER(1024, 3) AS HYBRID_TABLE_GB,
    (STORAGE_BYTES + STAGE_BYTES + FAILSAFE_BYTES + HYBRID_TABLE_STORAGE_BYTES) / POWER(1024, 3) AS TOTAL_STORAGE_GB,
    
    -- Cost calculation
    ((STORAGE_BYTES + STAGE_BYTES + FAILSAFE_BYTES + HYBRID_TABLE_STORAGE_BYTES) / POWER(1024, 4)) 
    * {{ var('snowflake_storage_rate_usd_per_tb_per_month', 40.00) }} / 30 AS ESTIMATED_DAILY_COST_USD
    
FROM combined_storage