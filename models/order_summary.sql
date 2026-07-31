select
    status,
    count(*) as order_count,
    sum(amount) as total_order_value
from {{ ref('orders') }}
group by status
