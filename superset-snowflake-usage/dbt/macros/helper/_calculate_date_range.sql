{% macro _calculate_date_range(base_date, offset_days=0, range_days=0) %}
    {#
    Calculate start and end dates based on base date, offset, and range.
    Returns tuple of (start_date_str, end_date_str) formatted for SQL.
    
    Logic:
    - offset_days: shifts the base date
    - range_days: expands the range from the offset date
    - if range_days < 0: range goes backward from offset date
    - if range_days > 0: range goes forward from offset date
    #}
    {%- set base_dt = _parse_date(base_date) -%}
    
    {%- if range_days != 0 -%}
        {%- if range_days < 0 -%}
            {# Negative range: start earlier, end at offset #}
            {%- set start_dt = base_dt + modules.datetime.timedelta(days=range_days + offset_days) -%}
            {%- set end_dt = base_dt + modules.datetime.timedelta(days=offset_days) -%}
        {%- else -%}
            {# Positive range: start at offset, end later #}
            {%- set start_dt = base_dt + modules.datetime.timedelta(days=offset_days) -%}
            {%- set end_dt = base_dt + modules.datetime.timedelta(days=range_days + offset_days) -%}
        {%- endif -%}
    {%- else -%}
        {# No range: single date with offset #}
        {%- set start_dt = base_dt + modules.datetime.timedelta(days=offset_days) -%}
        {%- set end_dt = start_dt -%}
    {%- endif -%}
    
    {{ return([_format_date_for_sql(start_dt), _format_date_for_sql(end_dt)]) }}
{% endmacro %}
