{{ config(alias="agents") }}

select
       agentid,
       is_contractor,
       agent_fees
from {{ source("ecommerce", "agents") }}