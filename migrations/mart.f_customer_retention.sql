create table if not exists mart.f_customer_retention (
	period_id smallint not null,
	period_name smallint not null,
	item_id integer,
	new_customers_count integer,
	returning_customers_count integer,
	refunded_customer_count integer,
	new_customers_revenue numeric(12,2),
	returning_customers_revenue numeric(12,2),
	customers_refunded integer
);

insert into mart.f_customer_retention (period_id, period_name, item_id,
                                       new_customers_count, returning_customers_count, refunded_customer_count,
                                       new_customers_revenue, returning_customers_revenue,
									   customers_refunded)
select
	period_id, period_name, item_id,
    new_customers_count, returning_customers_count, refunded_customer_count,
    new_customers_revenue, returning_customers_revenue,
    customers_refunded
from
	(
	select
		period_id,
		period_name,
		item_id,
		count(*) filter(where status = 'shipped' and orders = 1) as new_customers_count,
		count(*) filter(where status = 'shipped' and orders > 1) as returning_customers_count,
		count(*) filter(where status = 'refunded') as refunded_customer_count,
		sum(case when status = 'shipped' and orders = 1 then sum_payment_amount else 0 end) as new_customers_revenue,
		sum(case when status = 'shipped' and orders > 1 then sum_payment_amount else 0 end) as returning_customers_revenue,
		coalesce(sum(orders) filter(where status = 'refunded'), 0) as customers_refunded,
		MD5((period_id,period_name)::text) as uniq_id
	from 
		(
		select
		    period_id,
		    period_name,
		    item_id,
		    customer_id,
		    status,
		    count(*) as orders,
		    sum(payment_amount) as sum_payment_amount
		from
		    (
		    select uol.*, date_part('week', uol.date_time::timestamp) as period_id,
		    			  date_part('year', uol.date_time::timestamp) as period_name
		    from staging.user_order_log uol
            where uol.date_time::Date = '{{ds}}'
		    ) as t1
		group by period_id, period_name, item_id, customer_id, status
		) as t2
	group by period_id, period_name, item_id
	) as t3
where uniq_id not in (select MD5((period_id,period_name)::text) as uniq_id from mart.f_customer_retention);
