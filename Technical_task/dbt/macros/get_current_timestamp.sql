{% macro get_current_timestamp_utc() %}
    TO_TIMESTAMP_NTZ(CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()))
{% endmacro %}
