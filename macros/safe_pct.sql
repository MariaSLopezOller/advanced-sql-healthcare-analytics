{#- Percentage that returns NULL instead of failing when the denominator is 0. -#}
{% macro safe_pct(numerator, denominator, decimals=1) -%}
    round(100.0 * ({{ numerator }}) / nullif({{ denominator }}, 0), {{ decimals }})
{%- endmacro %}
