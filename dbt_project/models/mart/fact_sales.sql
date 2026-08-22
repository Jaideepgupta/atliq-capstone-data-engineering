select
    order_item_id,
    order_id,
    customer_id,
    product_id,
    order_date,
    status,
    quantity,
    item_price,
    gross_revenue,
    supplier_cost,

    cast(
        gross_revenue - (quantity * supplier_cost)
        as decimal(14,2)
    ) as gross_profit,

    cast(
        100.0 *
        (gross_revenue - (quantity * supplier_cost))
        / nullif(gross_revenue, 0)
        as decimal(10,2)
    ) as gross_margin_pct

from {{ ref('int_sales_enriched') }}