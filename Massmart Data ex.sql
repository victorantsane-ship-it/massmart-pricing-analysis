-- Massmart Data Analysis

select *
from massmart_advanced_pricing_dataset_2024
;

-- Creating new table for shorter naming

create table massmart_pricing
like massmart_advanced_pricing_dataset_2024
;

select *
from massmart_pricing
;

insert massmart_pricing
select *
from massmart_advanced_pricing_dataset_2024
;

-- Preview of a few rows
select *
from massmart_pricing
limit 15
;

-- Describe data type per column
describe massmart_pricing;

-- count total rows in dataset
select count(*) total_rows
from massmart_pricing
;

-- check for nulls or missing data
select 
	sum(case when Brand is null then 1 else 0 end) null_product,
	sum(case when category is null then 1 else 0 end) null_categoty,
	sum(case when Massmart_Price is null then 1 else 0 end) null_prices,
    sum(case when Competitor_Price is null then 1 else 0 end) null_Comp_prices,
    sum(case when Cost_Price is null then 1 else 0 end) null_cost,
    sum(case when SKU_ID is null then 1 else 0 end) null_ID,
    sum(case when Gross_Margin is null then 1 else 0 end) null_margins,
    sum(case when Units_Sold is null then 1 else 0 end) null_units,
    sum(case when Customer_Segment is null then 1 else 0 end) null_Segments
from massmart_pricing
;

-- Search for duplicate emtries
select Brand, Category, month(`Date`) as month, count(*) RecordCount
from massmart_pricing
group by Brand, Category, month(`Date`)
having count(*) > 1
;

with flagged as(
	select *,
			row_number() over (
				partition by Brand, Category, SKU_ID, month(`Date`)
                order by Transaction_ID
			) rn
	from massmart_pricing
)
select *
from flagged
where rn > 1
order by Brand, Category, `Date`
;

select *
from massmart_pricing
where Transaction_ID = 'TXN102303';

-- Only transaction ID can be unique in the data so checks should be done in Transaction_ID column

select Transaction_ID, count(*) RecordCount
from massmart_pricing
group by Transaction_ID
having count(*) > 1
;

-- Check for zeros or negative prices and sales
select *
from massmart_pricing
where Massmart_Price <= 0
	or Competitor_Price <= 0
    or Cost_Price <= 0
    or Units_Sold < 0
;

-- Analysis

select *
from massmart_pricing
;

-- Average margin by category
select Category, round(avg(gross_margin), 2) avg_margin
from massmart_pricing
group by Category
order by avg_margin desc
;

-- Average margin by month
select month(`Date`) Month_, round(avg(gross_margin), 2) avg_margin
from massmart_pricing
group by Month_
;

-- Revenue per category
select Category, sum(Units_Sold) Tot_Units, round(sum(Massmart_Price * Units_Sold), 2) Tot_Revenue
from massmart_pricing
group by Category
order by Tot_Revenue desc
;

-- Massmart prices vs competitor prices per category
select Category, round(avg(Cost_Price), 2) Avg_Cost, round(avg(Massmart_Price),2) Avg_MassmartPrice, round(avg(Competitor_Price), 2) Avg_CompetitorPrice,
case
	when round(avg(Massmart_Price),2) < round(avg(Competitor_Price), 2) then 'Cheaper'
    when round(avg(Massmart_Price),2) > round(avg(Competitor_Price), 2) then 'More Expensive'
	Else 'Equal'
end Price_Parity
from massmart_pricing
group by Category
order by Avg_Cost desc
;

select month(`Date`), round(avg(Cost_Price), 2) Avg_Cost, round(avg(Massmart_Price),2) Avg_MassmartPrice, round(avg(Competitor_Price), 2) Avg_CompetitorPrice,
case
	when round(avg(Massmart_Price),2) < round(avg(Competitor_Price), 2) then 'Cheaper'
    when round(avg(Massmart_Price),2) > round(avg(Competitor_Price), 2) then 'More Expensive'
	Else 'Equal'
end Price_Parity
from massmart_pricing
group by month(`Date`)
;

-- Top Opportunity SKUs
select SKU_ID, Category, round(avg(Massmart_Price),2) Avg_MassmartPrice, round(avg(Competitor_Price), 2) Avg_CompetitorPrice,
round(avg(Massmart_Price - Competitor_Price),2) Price_diff, round(avg(Gross_Margin),2) Margin
from massmart_pricing
group by SKU_ID, Category
order by Price_diff desc
limit 15
;

-- Promotional Effectiveness
select SKU_ID, Category, sum(Units_Sold) Units, round(avg(Gross_Margin),2) Margin
from massmart_pricing
where Promotion_Flag = 1
group by SKU_ID, Category
order by Units desc
;

select Promotion_Flag, SKU_ID, Category, sum(Units_Sold) Units, round(avg(Gross_Margin),2) Margin,
round(sum(Massmart_Price * Units_Sold), 2) Tot_Revenue
from massmart_pricing
-- where Promotion_Flag = 1
group by Promotion_Flag, SKU_ID, Category
order by Promotion_Flag desc
;


-- Promotion Effectiveness: Compare Promoted vs Non-Promoted Performance
WITH base AS (
    SELECT 
        Promotion_Flag, SKU_ID, Category, SUM(Units_Sold) AS Total_Units, ROUND(AVG(Gross_Margin), 2) AS Avg_Margin, 
        ROUND(SUM(Massmart_Price * Units_Sold), 2) AS Total_Revenue
    FROM massmart_pricing
    GROUP BY Promotion_Flag, SKU_ID, Category
)
SELECT 
    b.SKU_ID,
    b.Category,
    SUM(CASE WHEN b.Promotion_Flag = 1 THEN b.Total_Units ELSE 0 END) AS Promo_Units,
    SUM(CASE WHEN b.Promotion_Flag = 0 THEN b.Total_Units ELSE 0 END) AS NonPromo_Units,
    SUM(CASE WHEN b.Promotion_Flag = 1 THEN b.Total_Revenue ELSE 0 END) AS Promo_Revenue,
    SUM(CASE WHEN b.Promotion_Flag = 0 THEN b.Total_Revenue ELSE 0 END) AS NonPromo_Revenue,
    ROUND(
        CASE 
            WHEN SUM(CASE WHEN b.Promotion_Flag = 0 THEN b.Total_Revenue ELSE 0 END) = 0 THEN NULL
            ELSE 
                (SUM(CASE WHEN b.Promotion_Flag = 1 THEN b.Total_Revenue ELSE 0 END) /
                 SUM(CASE WHEN b.Promotion_Flag = 0 THEN b.Total_Revenue ELSE 0 END) - 1) * 100
        END, 2
    ) AS Promo_Revenue_Growth_Percent
FROM base b
GROUP BY b.SKU_ID, b.Category
ORDER BY Promo_Revenue_Growth_Percent DESC
;

-- Promotion effectiveness calcultions simplified
select SKU_ID, Category, round(avg(Massmart_Price), 2) Avg_MassmartPrice, round(avg(Competitor_Price), 2) Avg_CompetitorPrice,
sum(Units_Sold) Total_Units,
sum(case when Promotion_Flag = 1 then Units_Sold else 0 end) Promo_Units,
sum(case when Promotion_Flag = 0 then Units_Sold else 0 end) Non_Promo_Units,
round(sum(case when Promotion_Flag = 1 then Massmart_Price * Units_Sold else 0 end), 2) Promo_Revenue,
round(sum(case when Promotion_Flag = 0 then Massmart_Price * Units_Sold else 0 end), 2) NoPromo_Revenue,
round(
	case 
		when sum(case when Promotion_Flag = 0 then Massmart_Price * Units_Sold else 0 end) = 0 then null 
        else
			((sum(case when Promotion_Flag = 1 then Massmart_Price * Units_Sold else 0 end) -
			  sum(case when Promotion_Flag = 0 then Massmart_Price * Units_Sold else 0 end))/
              sum(case when Promotion_Flag = 0 then Massmart_Price * Units_Sold else 0 end)) * 100
		end, 2) PromoRevenue_Uplift
from massmart_pricing
group by SKU_ID, Category
order by PromoRevenue_Uplift desc
;


select SKU_ID, Category, year(`Date`) Year_, month(`Date`) Month_, round(avg(Massmart_Price), 2) Avg_MassmartPrice, round(avg(Competitor_Price), 2) Avg_CompetitorPrice,
sum(Units_Sold) Total_Units, ROUND(AVG(Gross_Margin), 2) AS Avg_Margin, ROUND(SUM(Massmart_Price * Units_Sold), 2) AS Total_Revenue,
sum(case when Promotion_Flag = 1 then Units_Sold else 0 end) Promo_Units,
sum(case when Promotion_Flag = 0 then Units_Sold else 0 end) Non_Promo_Units
from massmart_pricing
group by SKU_ID, Category, Year_, Month_
order by SKU_ID
;