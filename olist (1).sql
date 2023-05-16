alter table product
drop column F4

alter table orders
drop column F8

--count of duplicated review_id 
select count(review_id) as coun
from order_reviews
group by review_id
having count(review_id)>1

--delete all duplicated review_id
WITH cte AS (
    SELECT 
        review_id,
        ROW_NUMBER() OVER (
            PARTITION BY 
                review_id
  
            ORDER BY 
                review_id
        ) row_num
     FROM 
        order_reviews
)
DELETE FROM cte
WHERE row_num > 1;




--1.Selecting payments made by "boleto" or "voucher"
select*from payment
where payment_type='boleto' or payment_type='voucher'

--2.Selecting orders approved by Olist in 2017 only
select*from orders
where order_purchase_timestamp between '2017-01-1 00:00:00' and '2017-12-31 11:59:59'

--3.Checking the percentage of reviews that have no comments

select
    review_score,
    cast(count(review_id) * 100.0 / sum(count(review_id)) over()  as decimal(18, 2)) as Perc
from order_reviews
where review_comment_message is null
group by review_score
order by perc desc

--4.Checking how many orders came from the State of São Paulo but not from the City of São Paulo
select c.customer_state,count(o.order_id)  as number_of_orders
from customer c,orders o
where c.customer_id=o.customer_id and c.customer_state='SP' and c.customer_city!='sao paulo'
group by c.customer_state

--5.Selecting the amount of purchases that were over 1000, by each customer and their respective order, state, and the product category

select c.customer_id,o.order_id,c.customer_state,pro.product_category_name ,sum(p.payment_value) as total_payment
from orders o,payment p,product pro,customer c,item i,order_payment op,order_item oi
where o.customer_id=c.customer_id and o.order_id=op.order_id and p.payment_id=op.payment_id and i.product_id=pro.product_id
and o.order_id=oi.order_id and i.item_id=oi.item_id 
group by c.customer_id,o.order_id,c.customer_state,pro.product_category_name 
having sum(p.payment_value) >1000

--6.what is the most&least purchased product

select Top 1 p.product_category_name,count(oi.order_id) TS
from product p,item i,order_item oi
where p.product_id=i.product_id and i.item_id=oi.item_id
group by p.product_category_name
order by TS Desc

--7 what is the least purchased product
select Top 1 p.product_category_name,count(oi.order_id) TS
from product p,item i,order_item oi
where p.product_id=i.product_id and i.item_id=oi.item_id
group by p.product_category_name
order by TS Asc


--8 Avg delivery time
alter FUNCTION ufn_average_delivery_time()
RETURNS FLOAT
AS
BEGIN
    DECLARE @avg_delivery_time FLOAT

    SELECT @avg_delivery_time = AVG(DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date))
    FROM orders o
    WHERE o.order_status = 'delivered'

    RETURN @avg_delivery_time
END

select * from orders

select dbo.ufn_average_delivery_time() as avg_del
-------------------------------------------
--create function to display customers for each state 
alter function get_customer(@state varchar(50))
returns table 
as
return
( select customer_id from customer )
select * from get_customer('SP')

--عرض تفصيلي لمعلومات الشحن لمجموعة معينة من الموردين 9 
--Detailed presentation of shipping information for a specific group of suppliers

create view V_sellers
as 
select o.order_purchase_timestamp , o.order_delivered_carrier_date,
o.order_delivered_customer_date,o.order_estimated_delivery_date,o.order_approved_at
from orders o , order_item oi ,seller s,item i
where o.order_id=oi.order_id and oi.item_id=i.item_id 
and i.seller_id=s.seller_id and s.seller_id between '00fc707aaaad2d31347cf883cd2dfe10' and'05730013efda596306417c3b09302475'


--calling view
select* from V_sellers


--Delivery delay statistics

alter view delivery_delay_state
as 
select DATEDIFF(day,order_delivered_customer_date,order_estimated_delivery_date) as DI
from orders
where order_status='delivered' and order_delivered_customer_date>order_estimated_delivery_date 

-- calling
select * from delivery_delay_state

-- Number of customers in each state
create view cus_state
as 
select customer_state, count(customer_id) Num_cus
from customer
group by customer_state

--calling
select*from cus_state


-- select details of customer
alter proc order_details_by_customer @id varchar(155)
as
select o.order_id,o.order_purchase_timestamp,o.order_status,o.order_delivered_customer_date,p.product_id,p.product_category_name,
i.price,i.freight_value
from orders o,product p,item i,order_item oi,customer c
where o.order_id=oi.order_id and i.product_id=p.product_id and c.customer_id=@id and o.customer_id=c.customer_id

 order_details_by_customer @id='79464312f42f788e5138a105761846e4'

select *from orders

--
-- select details of product
create PROCEDURE GetCustomerOrders
(
@customer_id varchar(155)
)
AS
BEGIN
SELECT product.product_category_name,product.product_id,product.product_weight_g
FROM product, item,orders,order_item where product.product_id = item.product_id and order_item.order_id = orders.order_id
and orders.customer_id = @customer_id;
END

GetCustomerOrders @customer_id='79464312f42f788e5138a105761846e4'


select*from item
----------------------------------------------------
--/1/--create trigger to update the available products

alter TRIGGER update_product_availability
ON item
instead of  UPDATE
AS
select
'can not update item'
--Test
update item
set quantity = 2
where item_id = 'a1'

--/2/--create trigger to prevent alter on database
create trigger prevent_alter
on database 
after alter_table
as 
rollback
select
'can not alter in table'
--Test
alter table orders
add name varchar(50)
--------------------------
--create cursor get star to review_score

-- Declare variables
DECLARE @score float
-- Declare cursor
DECLARE review_cursor CURSOR FOR 
SELECT review_score  FROM order_reviews

-- Open cursor
OPEN review_cursor

-- Fetch first row
FETCH review_cursor INTO @score

-- Loop through results
WHILE @@FETCH_STATUS = 0
BEGIN
    if 
	 @score >=4
	select review_score=concat('*',@score)
	fetch review_cursor into @score
end
CLOSE review_cursor
DEALLOCATE review_cursor
-----------------------------------------------------------
--create rule to prevent freight_value being less than 10
create rule r1 as @freight_value>10
go
sp_bindrule r1, 'item.freight_value'
----------------------------------------------------------
--craete rule to restrict the payment_type

create rule r2 as @payment_type= 'credit_card'or @payment_type='boleto'
go
sp_bindrule r2, 'payment.payment_type'
----------------------------------------------------------
--create index
create unique index x1
on orders (customer_id)
--------------------
create  nonclustered index in2
on payment(payment_type)
-------------------------





