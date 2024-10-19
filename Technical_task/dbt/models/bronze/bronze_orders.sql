{{ config(alias="orders") }}

select orderid, 
       productid,
       customerid,
       createdat
from {{ source("ecommerce", "orders") }}
