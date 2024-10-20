-- dbt Model File

{{ config(materialized='incremental', unique_key='orderid') }}


with

orders as (
    -- a raw transactional fact table for orders being placed i.e. created
    select 
       orderid, ----added column names instead of *
       productid,
       customerid,
       createdat
    from {{ ref('bronze_orders') }}  --table is not new, using ref 
    {% if is_incremental() %}
       where createdat > (select max(createdat) - INTERVAL '1day' from {{ this }})  -- Fetch only updated records
    {% endif %}
),

fulfillments as (
    -- a raw consolidated fact table with three events that occur in sequence:
    -- packaged, shipped, delivered, in that order
    -- this table has a 1 to many relationship with orders
    select 
        timestamp, --added column names instead of *
        orderid,
        event_name,
        agentid 
    from {{ ref('bronze_fulfillments') }} --added reference
),

agents as (
    -- a raw table with delivery agent details including agent fees, agents can be employees
    -- or contractors; all fulfillments have a related agent who processed the order at that phase
    select 
       agentid, ----added column names instead of *
       is_contractor,
    from {{ ref('bronze_agents') }} --added reference
),

date_spine as (
    -- a utility table that has one record for every day between today and 5 years ago
    select 
       date_day --added col name instead of *
    from analytics.dbt.util_days
),

products as (
    -- a refined product dimension table
    select 
        products.product_id,  --added col names instead of *
        products.product_name,
        products.product_category,
        products.product_subcategory,
    from analytics.dbt.dim_products
),

customers as (
    -- a refined customer dimension table
    select 
        customer_id --added col names
        country
     from analytics.dbt.dim_customers
),

joined as (
select
    orders.orderid,
    orders.productid,
    orders.customerid,
    orders.createdat,
    min(packaged.timestamp) as packaged,
    min(shipped.timestamp) as shipped,
    min(delivered.timestamp) as delivered,
    min(packaged.agentid) as packaged_agentid,
    min(shipped.agentid) as shipped_agentid,
    min(shipped.agentid) as delivered_agentid
from orders
left join fulfillments as packaged
on orders.orderid = packaged.orderid
and packaged.event_name = 'order_packaged' -- move condition to join for performance
left join fulfillments as shipped
on orders.orderid = shipped.order_id
and shipped.event_name = 'order_shipped' --move condition to join for performance
left join fulfillments as delivered
on orders.orderid = delivered.order_id
and delivered.event_name = 'order_delivered' --move condition to join for performance
-- set the grain to one record per order
group by 1,2,3,4
),

order_metrics as (
select 
    joined.orderid,  --change * for col names
    joined.productid,
    joined.customerid,
    date_diff(joined.createdat, joined.packaged, day) as days_to_pack, --added alias joined
    date_diff(joined.packaged, joined.shipped, day) as days_to_ship, --added alias joined
    date_diff(joined.createdat, join.delivered, day) as days_to_deliver, --added alias joined
    customers.country =  'United States' as is_us_customer, 
    -- determine if a contractor was used to fulfill the delivery
    packaged_agents.is_contractor or
        shipped_agents.is_contractor or
        delivered_agents.is_contractor as has_contractor_support
from joined
left join agents as packaged_agents
    on joined.packaged_agentid = packaged_agents.agent_id
left join agents as shipped_agents
    on joined.shipped_agentid = shipped_agents.agent_id
left join agents as delivered_agents
    on joined.delivered_agentid = delivered_agents.agent_id
left join customers on joined.customerid = customers.customer_id
),

-- Create daily product summary, with one record for every combination or product and day even if
-- there were no products sold on that day
final as (
    select date_spine.date_day,
        products.product_id,
        products.product_name,
        products.product_category,
        products.product_subcategory,
        coalesce(avg(days_to_pack), 0) as avg_days_to_pack, --added coalesce to handle situation with no sales
        coalesce(avg(days_to_ship), 0) as avg_days_to_ship,  --added coalesce to handle situation with no sales
        coalesce(avg(days_to_deliver), 0) as avg_days_to_deliver  --added coalesce to handle situation with no sales
         coalesce(avg(case when is_us_customer then days_to_pack else null end), 0) as avg_us_days_to_pack, --added coalesce to handle situation with no sales
        coalesce(avg(case when is_us_customer then days_to_ship else null end), 0) as avg_us_days_to_ship, --added coalesce to handle situation with no sales
        coalesce(avg(case when is_us_customer then days_to_deliver else null end), 0) as avg_us_days_to_deliver,  --added coalesce to handle situation with no sales
        coalesce(avg(case when has_contractor_support then days_to_pack else null end), 0) as avg_contractor_days_to_pack,  --added coalesce to handle situation with no sales
        coalesce(avg(case when has_contractor_support then days_to_ship else null end), 0) as avg_contractor_days_to_ship,  --added coalesce to handle situation with no sales
        coalesce(avg(case when has_contractor_support then days_to_deliver else null end), 0) as avg_contractor_days_to_deliver,  --added coalesce to handle situation with no sales
         {{ get_current_timestamp() }} as current_timestamp_utc-- adding the current UTC timestamp from macros
    from date_spine
    cross join products --cross join is good here, as we need to see all records, even when there were no products sold
    left join order_metrics
        on date_spine.date_day = date(order_metrics.createdat)
        and products.product_id = order_metrics.productid
    group by 1,2,3,4,5
)

select 
    final.date_day,
    final.product_id,
    final.product_name,
    final.product_category,
    final.product_subcategory,
    final.avg_days_to_pack,
    final.avg_days_to_ship,
    final.avg_days_to_deliver,
    final.avg_us_days_to_pack,
    final.avg_us_days_to_ship,
    final.avg_us_days_to_deliver,
    final.avg_contractor_days_to_pack,
    final.avg_contractor_days_to_ship,
    final.avg_contractor_days_to_deliver,
    final.current_timestamp_utc --new column 
 from final
