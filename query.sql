SELECT 
ARRAY_AGG(t.id), i.symbol, ROUND(SUM(t.quantity),2) total_units, ROUND(AVG(t.price),2) average_price, 
ROUND(SUM(t.invested_amount),2) total_invested_amt
FROM transactions t 
LEFT JOIN instruments i 
ON t.instrument_id = i.id
WHERE t.type = 'BUY' AND t.price_currency != 'USD'
GROUP BY i.symbol
ORDER BY i.symbol ASC;

-- Yet to be done tasks -
-- 1. Add a column in transactions table to store the app name in which the stock exists.