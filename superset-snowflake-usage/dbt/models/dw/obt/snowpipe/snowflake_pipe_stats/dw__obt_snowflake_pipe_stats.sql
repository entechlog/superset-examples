{{ config(
      alias = 'snowflake_pipe_stats'
	, materialized = 'view'
    , tags = ['dw', 'obt']
) }}


{% set credit_cost_per_unit = 3.00 %}

WITH combined_copy_history AS (
    SELECT
        DATE,
        ENVIRONMENT_NAME,
        DATABASE_NAME,
        SCHEMA_NAME,
        PIPE_NAME,
        SUM(FILE_SIZE) AS TOTAL_DATA_LOADED,
        COUNT(*) AS TOTAL_FILES_PROCESSED,
        SUM(PROCESSING_TIME_SECONDS) AS TOTAL_PROCESSING_TIME_SECONDS,
        SUM(ERROR_COUNT) AS TOTAL_ERROR_COUNT
    FROM
        {{ ref('dw__fact_snowflake_pipe_copy_history') }} f
        INNER JOIN {{ ref('dw__dim_date') }} AS d ON d.date_id = f.date_id
    GROUP BY
        DATE, ENVIRONMENT_NAME, DATABASE_NAME, SCHEMA_NAME, PIPE_NAME
),

combined_pipe_usage AS (
    SELECT
        DATE,
        DATABASE_NAME,
        SCHEMA_NAME,
        PIPE_NAME,
        SUM(CREDITS_USED) AS TOTAL_CREDITS_USED,
        SUM(BYTES_INSERTED) AS TOTAL_BYTES_INSERTED,
        SUM(FILES_INSERTED) AS TOTAL_FILES_INSERTED,
        SUM(CREDITS_USED) * {{ credit_cost_per_unit }} AS TOTAL_COST
    FROM
        {{ ref('dw__fact_snowflake_pipe_usage_history') }} f
        INNER JOIN {{ ref('dw__dim_date') }} AS d ON d.date_id = f.date_id
    GROUP BY
        DATE, DATABASE_NAME, SCHEMA_NAME, PIPE_NAME
)

SELECT
    ch.DATE,
    ch.ENVIRONMENT_NAME,
    ch.DATABASE_NAME,
    ch.SCHEMA_NAME,
    ch.PIPE_NAME,
    ch.TOTAL_DATA_LOADED,
    ch.TOTAL_DATA_LOADED / (1024 * 1024 * 1024) AS TOTAL_DATA_LOADED_GB,
    ch.TOTAL_DATA_LOADED / (1024 * 1024 * 1024 * 1024) AS TOTAL_DATA_LOADED_TB,
    ch.TOTAL_FILES_PROCESSED,
    ch.TOTAL_PROCESSING_TIME_SECONDS,
    ch.TOTAL_ERROR_COUNT,
    pu.TOTAL_CREDITS_USED,
    pu.TOTAL_BYTES_INSERTED,
    pu.TOTAL_FILES_INSERTED,
    pu.TOTAL_COST
FROM
    combined_copy_history ch
LEFT JOIN
    combined_pipe_usage pu ON 
        ch.DATE = pu.DATE AND 
        LOWER(TRIM(ch.PIPE_NAME)) = LOWER(TRIM(pu.PIPE_NAME)) AND 
        LOWER(TRIM(ch.DATABASE_NAME)) = LOWER(TRIM(pu.DATABASE_NAME)) AND 
        LOWER(TRIM(ch.SCHEMA_NAME)) = LOWER(TRIM(pu.SCHEMA_NAME))