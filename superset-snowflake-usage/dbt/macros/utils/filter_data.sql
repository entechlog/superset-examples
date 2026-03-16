{% macro filter_data(src_column_key, src_column_val=none, src_operator='=', offset_days=0, range_days=0) %}
    {#
    Generate WHERE clause for filtering data based on run_type.
    
    Parameters:
    - src_column_key: Column name to filter on (required)
    - src_column_val: Reference date for daily runs (format: 'YYYY-MM-DD' or 'YYYYMMDD')
    - src_operator: Comparison operator for single date filters (default: '=')
    - offset_days: Days to shift the reference date (can be negative)
    - range_days: Days to extend the filter range (negative = backward range)
    
    Run Types:
    - full-refresh: Returns "where 1=1" (no filtering)
    - daily: Uses src_column_val as reference date
    - backfill: Uses backfill_start_date and backfill_end_date variables
    - other: Defaults to daily behavior
    #}
    
    {%- set run_type = var("run_type", "daily") -%}
    
    {%- if run_type == 'full-refresh' -%}
        where 1=1
        
    {%- elif run_type == 'backfill' -%}
        {%- set start_date = var("backfill_start_date") -%}
        {%- set end_date = var("backfill_end_date") -%}
        
        {%- if range_days != 0 or offset_days != 0 -%}
            {# Apply offset/range to backfill dates #}
            {%- set start_range = _calculate_date_range(start_date, offset_days, 0) -%}
            {%- set end_range = _calculate_date_range(end_date, offset_days, range_days) -%}
            where {{ src_column_key }} between {{ start_range[0] }} and {{ end_range[1] }}
        {%- else -%}
            {# No offset/range adjustments #}
            where {{ src_column_key }} between '{{ start_date }}' and '{{ end_date }}'
        {%- endif -%}
        
    {%- else -%}
        {# Daily or default behavior #}
        {%- if src_column_val is none -%}
            {%- do exceptions.raise_compiler_error("src_column_val is required for run_type: " ~ run_type) -%}
        {%- endif -%}
        
        {%- set date_range = _calculate_date_range(src_column_val, offset_days, range_days) -%}
        
        {%- if range_days != 0 -%}
            where {{ src_column_key }} between {{ date_range[0] }} and {{ date_range[1] }}
        {%- else -%}
            where {{ src_column_key }} {{ src_operator }} {{ date_range[0] }}
        {%- endif -%}
    {%- endif -%}
    
{% endmacro %}