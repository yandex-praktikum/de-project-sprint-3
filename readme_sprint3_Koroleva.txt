
Скрипты SQL в папке migrations:
sprint_3_ya.project_Koroleva.sql -- реализация задания по этапу 1 и 2
mart.f_sales_inc.sql --скрипт для инкрементальной загрузки
mart.f_sales_hist.sql --скрипт для загрузки с историей
mart.f_customer_retention_inc.sql --скрипт для инкрементальной загрузки 
mart.f_customer_retention_hist.sql --скрипт для загрузки с историей

DAG "sprint_3_ya.project_Koroleva.py" в папке src/dags

Комментарии:
Этап 1 
Добавлено новое поле status в таблицу staging.user_order_log.
Добавлено новое поле refund в витрину mart.f_sales
Скрипт sprint_3_ya.project_Koroleva.sql

При загрузке из staging.user_order_log в витрину mart.f_sales суммы в полях quantity и payment_amount для записей со статусом refunded будем указывать с минусами.
Скрипт для инкрементальной загрузки mart.f_sales_inc.sql
Скрипт для загрузки с историей mart.f_sales_hist.sql. В исторических данных нет строк со статусом refunded, поле refund заполнится по умолчанию значением false.

В файле настройки DAG создал Для загрузки исторических данных в файл DAG добавляем второй DAG с префиксом "h_".

Меняем вызов в DAG:
update_f_sales = PostgresOperator(
        task_id='update_f_sales',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.f_sales_inc.sql", # было f_sales.sql
        parameters={"date": {business_dt}})

Меняем работу функций f_upload_data_to_staging, f_upload_data_to_staging_hist в DAG, чтобы можно было обновлять за выборочные дни без удаления и дублирования.
И удаляем ранее загруженные данные за эту дату в таблице user_order_log.
Для инкрементов:
	str_del = f"delete FROM {pg_schema}.{pg_table} WHERE date_time::date = '{date}'" 
	engine.execute(str_del)
Для исторических данных:
	str_del = f"delete FROM {pg_schema}.{pg_table} WHERE date_time::date < '{date}'" 
	engine.execute(str_del)

В процедуре загрузки исторических данных f_upload_data_to_staging_hist нужно подставить в URL файла вместо increment_id значение report_id, полученное ранее в f_get_report
increment_id = ti.xcom_pull(key='report_id')



Этап 2 - Реализовать новую витрину
Скрипт в файле sprint_3_ya.project_Koroleva.sql
Скрипт для инкрементальной загрузки mart.f_customer_retention_inc.sql
Скрипт для исторических данных mart.f_customer_retention_hist.sql

Добавляем в DAG (для исторической и инкрементальной загрузки):
    h_update_f_customer_retention = PostgresOperator(
        task_id='update_f_customer_retention',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.f_customer_retention_hist.sql",
        parameters={"date": {business_dt}} )

    update_f_customer_retention = PostgresOperator(
        task_id='update_f_customer_retention',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.f_customer_retention_inc.sql",
        parameters={"date": {business_dt}} )

И указываем в очереди задач:
    (
            h_print_info_task 
            >> h_generate_report
            >> h_get_report
            >> h_upload_user_order
            >> [h_update_d_item_table, h_update_d_city_table, h_update_d_customer_table]
            >> h_null_task
            >> [h_update_f_sales, h_update_f_customer_retention]
    )

    (
            print_info_task
             >> generate_report
             >> get_report
             >> get_increment
             >> upload_user_order_inc
             >> [update_d_item_table, update_d_city_table, update_d_customer_table]
             >> null_task
             >> [update_f_sales, update_f_customer_retention]
    )



Этап 3 - Поддержка идемпотентности
В функциях f_upload_data_to_staging, f_upload_data_to_staging_hist в DAG учли обновление данных за определённые дни без удаления и дублирования.
Удаляем данные в staging.user_order_log за определённую дату:
Для инкрементов:
	str_del = f"delete FROM {pg_schema}.{pg_table} WHERE date_time::date = '{date}'" 
	engine.execute(str_del)
Для исторических данных:
	str_del = f"delete FROM {pg_schema}.{pg_table} WHERE date_time::date < '{date}'" 
	engine.execute(str_del)

Для витрины mart.f_customer_retention выполняется удаление данных за соответствующую неделю:
	delete from mart.f_customer_retention 
	where f_customer_retention.period_id =
	   (select substr(d_calendar.week_of_year_iso, 1, 8) from mart.d_calendar where d_calendar.date_actual = '{{ds}}' ) ;

И загружаем новые данные:
   	from staging.user_order_log uol2 
	join mart.d_calendar on uol2.date_time::date = d_calendar.date_actual 
			and '{{ ds }}' between d_calendar.first_day_of_week and d_calendar.last_day_of_week
