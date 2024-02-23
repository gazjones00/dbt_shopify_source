{{ config(materialized='incremental') }}

with base as (

    select * 
    from {{ ref('stg_shopify__abandoned_checkout_discount_code_tmp') }}
    {% if is_incremental() %}
    WHERE _fivetran_synced >= (select max(_fivetran_synced) from {{ this }})
    {% endif %}
),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_shopify__abandoned_checkout_discount_code_tmp')),
                staging_columns=get_abandoned_checkout_discount_code_columns()
            )
        }}

        {{ fivetran_utils.source_relation(
            union_schema_variable='shopify_union_schemas', 
            union_database_variable='shopify_union_databases') 
        }}

    from base
),

final as (
    
    select 
        checkout_id,
        upper(code) as code,
        discount_id,
        amount,
        type,
        {{ dbt_date.convert_timezone(column='cast(created_at as ' ~ dbt.type_timestamp() ~ ')', target_tz=var('shopify_timezone', "UTC"), source_tz="UTC") }} as created_at,
        {{ dbt_date.convert_timezone(column='cast(updated_at as ' ~ dbt.type_timestamp() ~ ')', target_tz=var('shopify_timezone', "UTC"), source_tz="UTC") }} as updated_at,
        {{ dbt_date.convert_timezone(column='cast(_fivetran_synced as ' ~ dbt.type_timestamp() ~ ')', target_tz=var('shopify_timezone', "UTC"), source_tz="UTC") }} as _fivetran_synced,
        source_relation, 
        row_number() over(partition by checkout_id, upper(code) order by index desc) as index

    from fields
    
)

select *
from final
where index = 1

