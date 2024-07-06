insert into mart.f_sales (date_id, item_id, customer_id, city_id, quantity, payment_amount, status)
select
    date_id, item_id, customer_id, city_id, quantity, payment_amount, status
from
    (
    select date_id, item_id, customer_id, city_id, quantity, payment_amount, status,
           MD5((date_id,item_id,customer_id,city_id,quantity,payment_amount,status)::text) as uniq_id
    from
        (
        select
            dc.date_id as date_id, 
            uol.item_id as item_id,
            uol.customer_id as customer_id,
            uol.city_id as city_id,
            uol.quantity as quantity,
            case when status = 'shipped' then payment_amount::numeric(10,2)
            else ((-1)*payment_amount)::numeric(10,2) end as payment_amount,
            uol.status as status
        from staging.user_order_log uol
        left join mart.d_calendar as dc
            on uol.date_time::Date = dc.date_actual
        where uol.date_time::Date = '{{ds}}'
        ) as t1
    ) as t2
where uniq_id not in (select MD5((date_id,item_id,customer_id,city_id,quantity,payment_amount,status)::text) as uniq_id
                      from mart.f_sales);
