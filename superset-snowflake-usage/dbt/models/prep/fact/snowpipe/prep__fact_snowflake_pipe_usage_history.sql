{{ config(
      alias = 'snowflake_pipe_usage_history'
    , materialized = 'view'
    , tags = ['prep', 'fact']
) }}

WITH pipe_usage AS (
    SELECT
        DATE(START_TIME) AS LOAD_DATE,
        PIPE_ID,
        PIPE_NAME,
        START_TIME,
        END_TIME,
        CREDITS_USED,
        BYTES_INSERTED,
        FILES_INSERTED::FLOAT AS FILES_INSERTED
    FROM
        snowflake.account_usage.pipe_usage_history
    {{ filter_data(
        src_column_key = 'to_date(START_TIME)',
        src_operator = '=',
        src_column_val = "'" ~ var('batch_cycle_date') ~ "'"
    ) }}
),

pipes AS (
    SELECT
        PIPE_ID,
        PIPE_NAME,
        PIPE_CATALOG AS DATABASE_NAME,
        PIPE_SCHEMA AS SCHEMA_NAME
    FROM
        snowflake.account_usage.pipes
)

SELECT
    pu.LOAD_DATE,
    CASE
        WHEN SUBSTRING(p.DATABASE_NAME, 1, 3) IN ('DEV', 'STG', 'PRD') THEN SUBSTRING(p.DATABASE_NAME, 1, 3)
        WHEN UPPER(SUBSTRING(p.DATABASE_NAME, LENGTH(p.DATABASE_NAME) - 4, 5)) = '-TEST' THEN 'TEST'
        WHEN SUBSTRING(p.DATABASE_NAME, LENGTH(p.DATABASE_NAME) - 2, 3) = 'EST' THEN CONCAT('OLD-', 'TEST')
        ELSE CONCAT('OLD-', SUBSTRING(p.DATABASE_NAME, LENGTH(p.DATABASE_NAME) - 2, 3))
    END AS ENVIRONMENT_NAME,
    p.DATABASE_NAME,
    p.SCHEMA_NAME,
    pu.PIPE_NAME,
    pu.START_TIME,
    pu.END_TIME,
    pu.CREDITS_USED,
    pu.BYTES_INSERTED,
    pu.FILES_INSERTED
FROM
    pipe_usage pu
JOIN
    pipes p
ON
    pu.PIPE_ID = p.PIPE_ID