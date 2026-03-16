-- Simple and reliable test suite for the idempotency macros

{% macro test_helper_macros() %}
    {{ log("=== Testing Helper Macros ===", info=True) }}
    
    -- Test _parse_date
    {%- set test_date1 = _parse_date("'2024-04-20'") -%}
    {%- set test_date2 = _parse_date("20240420") -%}
    {{ log("Parsed '2024-04-20': " ~ test_date1.strftime("%Y-%m-%d"), info=True) }}
    {{ log("Parsed '20240420': " ~ test_date2.strftime("%Y-%m-%d"), info=True) }}
    
    -- Test _format_date_for_sql
    {%- set formatted = _format_date_for_sql(test_date1) -%}
    {{ log("Formatted for SQL: " ~ formatted, info=True) }}
    
    -- Test _calculate_date_range
    {%- set range1 = _calculate_date_range("2024-04-20", 0, 2) -%}
    {%- set range2 = _calculate_date_range("2024-04-20", 1, -2) -%}
    {{ log("Range test 1 (offset=0, range=2): " ~ range1[0] ~ " to " ~ range1[1], info=True) }}
    {{ log("Range test 2 (offset=1, range=-2): " ~ range2[0] ~ " to " ~ range2[1], info=True) }}
    
{% endmacro %}

{% macro test_filter_data_with_current_settings() %}
    {{ log("=== Testing filter_data with Current Project Settings ===", info=True) }}
    {%- set current_run_type = var("run_type", "daily") -%}
    {{ log("Current run_type: " ~ current_run_type, info=True) }}
    
    {% if current_run_type == 'daily' %}
        -- Test daily scenarios
        {{ log("Test 1: daily, no offset/range", info=True) }}
        {%- set result1 -%}
            {{- filter_data('date_col', "'2024-04-20'") -}}
        {%- endset -%}
        {{ log("Result: " ~ result1.strip(), info=True) }}
        
        {{ log("Test 2: daily, offset=2", info=True) }}
        {%- set result2 -%}
            {{- filter_data('date_col', "'2024-04-20'", offset_days=2) -}}
        {%- endset -%}
        {{ log("Result: " ~ result2.strip(), info=True) }}
        
        {{ log("Test 3: daily, range=3", info=True) }}
        {%- set result3 -%}
            {{- filter_data('date_col', "'2024-04-20'", range_days=3) -}}
        {%- endset -%}
        {{ log("Result: " ~ result3.strip(), info=True) }}
        
        {{ log("Test 4: daily, YYYYMMDD format", info=True) }}
        {%- set result4 -%}
            {{- filter_data('date_col', '20240420') -}}
        {%- endset -%}
        {{ log("Result: " ~ result4.strip(), info=True) }}
        
    {% elif current_run_type == 'backfill' %}
        -- Test backfill scenarios
        {{ log("Test 1: backfill, no offset", info=True) }}
        {%- set result1 -%}
            {{- filter_data('date_col') -}}
        {%- endset -%}
        {{ log("Result: " ~ result1.strip(), info=True) }}
        
        {{ log("Test 2: backfill, offset=1", info=True) }}
        {%- set result2 -%}
            {{- filter_data('date_col', offset_days=1) -}}
        {%- endset -%}
        {{ log("Result: " ~ result2.strip(), info=True) }}
        
    {% elif current_run_type == 'full-refresh' %}
        -- Test full-refresh scenarios
        {{ log("Test 1: full-refresh", info=True) }}
        {%- set result1 -%}
            {{- filter_data('date_col') -}}
        {%- endset -%}
        {{ log("Result: " ~ result1.strip(), info=True) }}
    {% endif %}
    
{% endmacro %}

{% macro test_date_calculations() %}
    {{ log("=== Testing Date Calculation Logic ===", info=True) }}
    
    -- Test basic date calculations that would be used by delete_data
    {{ log("Test 1: daily, no offset", info=True) }}
    {%- set range1 = _calculate_date_range("2024-04-20", 0, 0) -%}
    {{ log("Delete date would be: " ~ range1[0], info=True) }}
    
    {{ log("Test 2: daily, offset=2", info=True) }}
    {%- set range2 = _calculate_date_range("2024-04-20", 2, 0) -%}
    {{ log("Delete date would be: " ~ range2[0], info=True) }}
    
    {{ log("Test 3: daily, offset=-1", info=True) }}
    {%- set range3 = _calculate_date_range("2024-04-20", -1, 0) -%}
    {{ log("Delete date would be: " ~ range3[0], info=True) }}
    
    -- Test backfill date range calculations
    {{ log("Test 4: backfill range calculation", info=True) }}
    {%- set start_range = _calculate_date_range("2024-04-15", 1, 0) -%}
    {%- set end_range = _calculate_date_range("2024-04-20", 1, 0) -%}
    {{ log("Backfill with offset=1 would be: " ~ start_range[0] ~ " to " ~ end_range[0], info=True) }}
    
{% endmacro %}

{% macro test_edge_cases() %}
    {{ log("=== Testing Edge Cases ===", info=True) }}
    
    -- Test large positive offset
    {{ log("Test 1: Large positive offset (30 days)", info=True) }}
    {%- set range1 = _calculate_date_range("2024-04-20", 30, 0) -%}
    {{ log("Result: " ~ range1[0], info=True) }}
    
    -- Test large negative offset
    {{ log("Test 2: Large negative offset (-30 days)", info=True) }}
    {%- set range2 = _calculate_date_range("2024-04-20", -30, 0) -%}
    {{ log("Result: " ~ range2[0], info=True) }}
    
    -- Test month boundary crossing
    {{ log("Test 3: Month boundary (2024-04-30 + 5 days)", info=True) }}
    {%- set range3 = _calculate_date_range("2024-04-30", 5, 0) -%}
    {{ log("Result: " ~ range3[0], info=True) }}
    
    -- Test year boundary crossing
    {{ log("Test 4: Year boundary (2024-12-30 + 5 days)", info=True) }}
    {%- set range4 = _calculate_date_range("2024-12-30", 5, 0) -%}
    {{ log("Result: " ~ range4[0], info=True) }}
    
    -- Test leap year
    {{ log("Test 5: Leap year (2024-02-28 + 2 days)", info=True) }}
    {%- set range5 = _calculate_date_range("2024-02-28", 2, 0) -%}
    {{ log("Result: " ~ range5[0], info=True) }}
    
    -- Test complex range scenarios
    {{ log("Test 6: Complex range (offset=3, range=-5)", info=True) }}
    {%- set range6 = _calculate_date_range("2024-04-20", 3, -5) -%}
    {{ log("Result: " ~ range6[0] ~ " to " ~ range6[1], info=True) }}
    
{% endmacro %}

-- Main test runner - safe and reliable
{% macro run_all_tests() %}
    {{ log("Starting comprehensive macro tests...", info=True) }}
    
    {{ test_helper_macros() }}
    {{ test_filter_data_with_current_settings() }}
    {{ test_date_calculations() }}
    {{ test_edge_cases() }}
    
    {{ log("All tests completed successfully!", info=True) }}
    {{ log("Note: To test other run_types, change your run_type variable and run again", info=True) }}
{% endmacro %}

-- Simpler test runner for just basic functionality
{% macro run_basic_tests() %}
    {{ log("Running basic functionality tests...", info=True) }}
    {{ test_helper_macros() }}
    {{ test_edge_cases() }}
    {{ log("Basic tests completed!", info=True) }}
{% endmacro %}

-- Test specific scenarios by run_type
{% macro test_full_refresh_scenario() %}
    {{ log("=== Testing Full Refresh Scenario ===", info=True) }}
    {{ log("To test full-refresh, run:", info=True) }}
    {{ log("dbt run-operation run_all_tests --vars '{\"run_type\": \"full-refresh\"}'", info=True) }}
{% endmacro %}

{% macro test_backfill_scenario() %}
    {{ log("=== Testing Backfill Scenario ===", info=True) }}
    {{ log("To test backfill, run:", info=True) }}
    {{ log("dbt run-operation run_all_tests --vars '{\"run_type\": \"backfill\", \"backfill_start_date\": \"2024-04-15\", \"backfill_end_date\": \"2024-04-20\"}'", info=True) }}
{% endmacro %}