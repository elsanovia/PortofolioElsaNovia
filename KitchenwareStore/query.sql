SELECT *
FROM toko_peralatan_dapur_project.orders
WHERE order_id is not null;

# Menghitung total ongkos kirim seluruh pelanggan dan rata-rata per pemesanan
SELECT product_name,
  SUM(shipping_fee) AS total_ongkos_kirim,
  AVG(shipping_fee) AS rata_rata_ongkos
FROM toko_peralatan_dapur_project.orders
WHERE product_name IS NOT NULL
GROUP BY product_name
ORDER BY 
  total_ongkos_kirim DESC,
  rata_rata_ongkos DESC;

# Menghitung produk terbanyak dengan status completed
## Berdasarkan unit terjual
SELECT
  product_name,
  status_clean,
  SUM(quantity) AS qty_transaction
FROM toko_peralatan_dapur_project.orders
WHERE status_clean = 'complete'
GROUP BY 
  product_name,
  status_clean
ORDER BY qty_transaction DESC;

## Berdasarkan revenue
SELECT 
  product_name,
  status_clean,
SUM(total_sales) AS revenue
FROM toko_peralatan_dapur_project.orders 
WHERE product_name is not null
  AND status_clean = 'complete' 
GROUP BY 
  product_name,
  status_clean
ORDER BY revenue DESC;

# Menghitung jumlah pesanan dan total revenue pada periode Oktober-Desember 2025
SELECT 
  COUNT(order_id) AS jumlah_pemesanan,
  SUM(total_sales) AS total_revenue
FROM toko_peralatan_dapur_project.orders
WHERE 
  sales_date BETWEEN '2025-10-01' AND '2025-12-31'
  AND status_clean = 'complete';

# Mengetahui kota dengan rata-rata ongkos kirim termahal dan selisih dengan kota paling murah
WITH ongkir_kota AS (
  SELECT city_clean,
  AVG(shipping_fee) AS rata_rata_ongkir
  FROM toko_peralatan_dapur_project.orders
  WHERE city_clean IS NOT NULL
  GROUP BY city_clean
)

SELECT
  MAX(rata_rata_ongkir) AS ongkir_termahal,
  MIN(rata_rata_ongkir) AS ongkir_termurah,
  MAX(rata_rata_ongkir) - MIN(rata_rata_ongkir) AS selisih_ongkir
FROM ongkir_kota;

# Menghitung total rupiah dari pesanan refund dan persentase terhadap gross sales setahun
SELECT
  SUM(CASE WHEN status_clean = 'refund' THEN price ELSE 0 END) AS total_rupiah_refund,
  SUM(price) AS gross_sales,
  (SUM(CASE WHEN status_clean = 'refund' THEN price ELSE 0 END) / SUM(price)) * 100 AS percentage_refund  
FROM toko_peralatan_dapur_project.orders;

# Mengetahui produk dengan rata-rata quantity per pemesanan tertinggi dengan syarat minimal 50 pesanan completed
SELECT
  product_name,
  category_clean,
  AVG(quantity) AS avarage_qty,
FROM toko_peralatan_dapur_project.orders
WHERE status_clean = 'complete'
GROUP BY
  product_name,
  category_clean
HAVING COUNT(*) >= 50
ORDER BY avarage_qty DESC;

# Mengetahui bulan dengan revenue tertinggi dari masing-masing kategori produk
WITH monthly_revenue AS (
  SELECT 
    category_clean,
    EXTRACT(MONTH FROM sales_date) AS sales_month,
    SUM(total_sales) AS total_revenue 
FROM toko_peralatan_dapur_project.orders
WHERE status_clean = 'complete'
GROUP BY
 category_clean,
 sales_month
),

ranking_month_revenue AS (
SELECT
  category_clean,
  sales_month,
  total_revenue,
  ROW_NUMBER() OVER(PARTITION BY category_clean ORDER BY total_revenue DESC) AS ranking
FROM monthly_revenue
)

SELECT
  category_clean,
  sales_month,
  total_revenue
FROM ranking_month_revenue
WHERE ranking = 1;

# Mengetahui jumlah produk teratas yang menyumbang 80% dari total revenue completed
## Menghitung total penjualan
WITH total_revenue AS (
  SELECT 
    product_name,
    SUM(total_sales) AS revenue
FROM toko_peralatan_dapur_project.orders
WHERE status_clean = 'complete'
GROUP BY product_name
),

## Menghitung total kumulatif penjualan
cumulative_revenue AS (
SELECT 
  product_name,
  revenue,
  SUM(revenue) OVER(ORDER BY revenue DESC) AS running_total,
  SUM(revenue) OVER() AS grand_total
FROM total_revenue
),

## Menghitung persentase penjualan
percentage_revenue AS (
SELECT 
  product_name,
  revenue,
  (running_total/grand_total) * 100 AS cumulative_percentage
FROM cumulative_revenue
)

## Menghitung produk yang menyumbang 80% dari total revenue
SELECT 
  product_name,
  revenue,
  cumulative_percentage
FROM percentage_revenue
WHERE cumulative_percentage <= 80
ORDER BY cumulative_percentage DESC;

# Mengetahui pelanggan yang memesan >5 pesanan completed dan rata-rata jeda hari antara 2 pesanan berturut-turut, beserta pelanggan dengan jeda rata-rata tersingkat
## Mengetahui pelanggan dengan pemesanan lebih dari 5
SELECT
  customer_name,
  COUNT(order_id) AS transaction_frequency
FROM toko_peralatan_dapur_project.orders
WHERE status_clean = 'complete'
GROUP BY customer_name
HAVING COUNT(order_id) > 5;

## Mengetahui rata-rata jeda hari antara 2 pesanan berturut-turut
WITH transaction_history AS (
  SELECT
    customer_name,
    sales_date,
    LAG(sales_date) OVER(PARTITION BY customer_name ORDER BY sales_date ASC) AS past_revenue
FROM toko_peralatan_dapur_project.orders
WHERE status_clean = 'complete'
),

difference_days AS (
  SELECT 
    customer_name, 
    sales_date,
    past_revenue,
    DATE_DIFF(sales_date, past_revenue, DAY) AS day_break
FROM transaction_history
WHERE past_revenue IS NOT NULL
)

SELECT 
AVG(day_break) AS avg_day_break
FROM difference_days;

## Mengetahui pelanggan dengan jeda rata-rata tersingkat
WITH transaction_history AS (
  SELECT
    customer_name,
    sales_date,
    LAG(sales_date) OVER(PARTITION BY customer_name ORDER BY sales_date ASC) AS past_revenue
FROM toko_peralatan_dapur_project.orders
WHERE status_clean = 'complete'
),

difference_days AS (
  SELECT 
    customer_name, 
    sales_date,
    past_revenue,
    DATE_DIFF(sales_date, past_revenue, DAY) AS day_break
FROM transaction_history
WHERE past_revenue IS NOT NULL
)

SELECT 
 customer_name,
 AVG(day_break) AS avg_day_break
FROM difference_days
GROUP BY customer_name
ORDER BY avg_day_break ASC
LIMIT 1;

# Mengetahui produk dengan refund rate tertinggi dan potensi revenue yang dapat diselamatkan jika refund rate produk turun ke rata-rata toko (~5%)
## Mengetahui produk dengan refund rate tertinggi 
SELECT
  product_name,
  COUNT(CASE WHEN status_clean = 'refund' THEN order_id END) AS total_refund,
  COUNT(order_id) AS total_order,
  ROUND(SAFE_DIVIDE(COUNT(CASE WHEN status_clean = 'refund' THEN order_id END),COUNT(order_id)) * 100, 2) AS refund_rate
FROM toko_peralatan_dapur_project.orders
GROUP BY product_name
ORDER BY refund_rate DESC;

## Mengetahui potensi revenue yang dapat diselamatkan jika refund rate produk turun ke rata-rata toko (~5%)
WITH refund_comparison AS (
  SELECT
    product_name,
    SUM(total_sales) AS total_product,
    SUM(CASE WHEN status_clean = 'refund' THEN total_sales ELSE 0 END) AS refund_money,
    SAFE_DIVIDE(SUM(CASE WHEN status_clean = 'refund' THEN total_sales ELSE 0 END), SUM(total_sales)) AS final_refund_rate
FROM toko_peralatan_dapur_project.orders
GROUP BY product_name
)

SELECT
  product_name,
  refund_money,
  final_refund_rate,
  ROUND((final_refund_rate - 0.05) * total_product, 2) AS potential_revenue
FROM refund_comparison
WHERE final_refund_rate > 0.05
ORDER BY potential_revenue DESC;

















