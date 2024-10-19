-- dbt Model File

{{ config(materialized='table') }}

with

orders as (
    -- a raw transactional fact table for orders being placed i.e. created
    select * from fivetran.ecommerce.orders
),

fulfillments as (
    -- a raw consolidated fact table with three events that occur in sequence:
    -- packaged, shipped, delivered, in that order
    -- this table has a 1 to many relationship with orders
    select * from fivetran.ecommerce.fulfillments
),

agents as (
    -- a raw table with delivery agent details including agent fees, agents can be employees
    -- or contractors; all fulfillments have a related agent who processed the order at that phase
    select * from fivetran.ecommerce.agents
),

date_spine as (
    -- a utility table that has one record for every day between today and 5 years ago
    select * from analytics.dbt.util_days
),

products as (
    -- a refined product dimension table
    select * from analytics.dbt.dim_products
),

customers as (
    -- a refined customer dimension table
    select * from analytics.dbt.dim_customers
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
on orders.orderid = packaged.order_id
left join fulfillments as shipped
on orders.orderid = shipped.order_id
left join fulfillments as delivered
on orders.orderid = delivered.order_id
where packaged.event_name = 'order_packaged'
and shipped.event_name = 'order_shipped'
and delivered.event_name = 'order_delivered'
-- set the grain to one record per order
group by 1,2,3,4
),

order_metrics as (
select *, 
    date_diff(createdat, packaged, day) as days_to_pack,
    date_diff(packaged, shipped, day) as days_to_ship,
    date_diff(createdat, delivered, day) as days_to_deliver,
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
        avg(days_to_pack) as avg_days_to_pack,
        avg(days_to_ship) as avg_days_to_ship,
        avg(days_to_deliver) as avg_days_to_deliver,
        avg(case when is_us_customer then days_to_pack else null end) as avg_us_days_to_pack,
        avg(case when is_us_customer then days_to_ship else null end) as avg_us_days_to_ship,
        avg(case when is_us_customer then days_to_deliver else null end) as avg_us_days_to_deliver,
        avg(case when has_contractor_support then days_to_pack else null end) as avg_contractor_days_to_pack,
        avg(case when has_contractor_support then days_to_ship else null end) as avg_contractor_days_to_ship,
        avg(case when has_contractor_support then days_to_deliver else null end) as avg_contractor_days_to_deliver
    from date_spine
    cross join products
    left join order_metrics
        on date_spine.date_day = date(order_metrics.createdat)
        and products.product_id = order_metrics.productid
    group by 1,2,3,4,5
)

select * from final