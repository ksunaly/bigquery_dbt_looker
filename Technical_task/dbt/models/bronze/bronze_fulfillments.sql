{{ config(alias="fulfillments") }}

select 
        timestamp, 
        orderid,
        event_name,
        agentid 

from {{ source("ecommerce", "fulfillments") }}