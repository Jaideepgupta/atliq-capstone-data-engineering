select
    oi.order_item_id,
    o.order_id,
    o.customer_id,
    oi.product_id,
    o.order_date,
    o.status,
    oi.quantity,
    oi.item_price,

    cast(
        oi.quantity * oi.item_price
        as decimal(14,2)
    ) as gross_revenue,

    p.product_name,
    p.category,
    p.unit_price,

    sp.supplier_name,
    sp.supplier_cost

from {{ ref('stg_order_items') }} oi

inner join {{ ref('stg_orders') }} o
    on oi.order_id = o.order_id

left join {{ ref('stg_products') }} p
    on oi.product_id = p.product_id

left join {{ ref('stg_supplier_price_list') }} sp
    on oi.product_id = sp.product_id