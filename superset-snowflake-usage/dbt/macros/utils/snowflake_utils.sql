{% macro get_environment_code(identifier) %}
    {% set env_keywords = {
        'DEV' : ['DEV', 'DEVELOP', 'DEVELOPMENT', 'SANDBOX', 'LOCAL'],
        'INT' : ['INT', 'INTEGRATION', 'CI', 'CD'],
        'TEST': ['TEST', 'QA', 'UAT', 'SIT'],
        'STG' : ['STG', 'STAGE', 'STAGING', 'PREPROD', 'PPRD'],
        'PRD' : ['PRD', 'PROD', 'PRODUCTION', 'LIVE'],
        'SYS' : ['SNOWFLAKE', 'CLOUD_SERVICES_ONLY', 'SNOWPIPE', 'TASK', 'AUTO']
    } %}

    CASE
    {%- for code, words in env_keywords.items() %}
        {# Build the pattern with a *capturing* group, which Snowflake supports #}
        {% set pattern = '.*(' ~ words | join('|') ~ ').*' %}
        WHEN REGEXP_LIKE({{ identifier }}, '{{ pattern }}', 'i') THEN '{{ code }}'
    {%- endfor %}
        ELSE 'OTHER'
    END
{% endmacro %}

{% macro get_storage_tier(total_storage_bytes_column) %}
    CASE
        WHEN {{ total_storage_bytes_column }} >= POWER(1024, 4) THEN 'High'
        WHEN {{ total_storage_bytes_column }} >= POWER(1024, 4) * 0.1 THEN 'Medium'
        WHEN {{ total_storage_bytes_column }} >= POWER(1024, 3) * 10 THEN 'Low'
        WHEN {{ total_storage_bytes_column }} >= POWER(1024, 3) THEN 'Minimal'
        ELSE 'Minimal'
    END
{% endmacro %}

{% macro get_utilization_pattern(active_hours_column) %}
    CASE 
        WHEN {{ active_hours_column }} >= 16 THEN 'High'
        WHEN {{ active_hours_column }} >= 8 THEN 'Medium'
        WHEN {{ active_hours_column }} >= 4 THEN 'Low'
        ELSE 'Minimal'
    END
{% endmacro %}