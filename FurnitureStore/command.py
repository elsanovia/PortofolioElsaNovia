import pandas as pd

df = pd.read_csv('data_furniture.csv')
print(df)

# DATA CLEANING
## Duplicate Data
## Mengecek jumlah data duplikat
total_duplicated = df.duplicated().sum()
print(total_duplicated)

# Missing Value
df['shipping_address'] = df['shipping_address'].fillna('Unknown')
print(df['shipping_address'])
## Mengecek jumlah missing value
total_unknown = (df['shipping_address'] == 'Unknown').sum()
print(total_unknown)

# Mengubah Tipe Data
df['sales_date'] = pd.to_datetime(df['sales_date'])
print(df['sales_date'])

df.info()

# AGGREGATING & PLOTTING
import matplotlib.pyplot as plt
import seaborn as sns

# Memisahkan nama kelurahan & kota
df['city'] = df['shipping_address'].str.split(',').str[-1].str.strip()
print(df['city'])

# Melakukan filter pada pesanan dengan status completed
df_completed = df[df['status'] == 'completed']
print(df_completed)

# Menghitung total pendapatan tiap kota
df_omset = df_completed.groupby('city')['total_sales'].sum().reset_index()
df_omset = df_omset.sort_values(by='total_sales', ascending=False)
print(df_omset)

# Membuat diagram omset penjualan tiap kota
## Membuat kanvas
plt.figure(figsize=(12, 6))

## Membuat bar chart dengan Seaborn
ax = sns.barplot(data=df_omset, x='total_sales', y='city', color='royalblue')
print(ax)

## Menambahkan judul dan label sumbu
plt.title('Total Omset Penjualan Tiap Kota', fontsize=14, fontweight='bold')
plt.xlabel('Total Omset', fontsize=12)
plt.ylabel('Kota', fontsize=12)

## Menambah label angka pada ujung tiap batang
for p in ax.patches:
  nilai = p.get_width()

# Mengubah format angka menjadi Juta atau Miliar
## Jika Miliar
if nilai >= 1e9:
  label_teks = f'Rp {nilai/1e9:.2f} Miliar'
## Jika Juta
elif nilai >= 1e6:
  label_teks = f'Rp {nilai/1e6:.2f} Juta'
else:
  label_teks = f'Rp {nilai:,.0f}'

# Menempel label pada ujung batang grafik
ax.annotate(label_teks,
  (nilai, p.get_y() + p.get_height() / 2.),
  ha='left', va='center',
  xytext=(5, 0), # Geser teks dikit ke kanan biar gak nempel banget sama batang
  textcoords='offset points',
  fontsize=10)

plt.show()

# DATA VISUALIZATION
# Melakukan filter untuk pesananan dengan status completed dan ada diskon
df_promo = df[(df['status'] == 'completed') & (df['discount'] > 0)]

# Melakukan group by pada nama produk
df_agg = df_promo.groupby('product_name').agg({
    ## Total Omset
    'total_sales': 'sum',
    ## Rata-rata Diskon
    'discount': 'mean',
    ## Rata-rata Kuantitas
    'quantity': 'mean'
}).reset_index()

# Mengurutkan omset tertinggi ke terendah
df_agg = df_agg.sort_values(by='total_sales', ascending=False)

# Mengetahui top 5 produk untuk business insight
print("Top 5 Produk Hasil Promosi:")
print(df_agg.head())
print("-" * 50)

# Membuat kanvas
fig, axes = plt.subplots(1, 2, figsize=(15, 6))

# Plot 1: Scatter Plot
sns.scatterplot(data=df_promo, x='price', y='total_sales', alpha=0.5, color='coral', ax=axes[0])
axes[0].set_title('Korelasi Harga Satuan vs Total Omset', fontsize=12, fontweight='bold')
axes[0].set_xlabel('Harga Satuan (Price)')
axes[0].set_ylabel('Total Omset')

# Plot 2: Box Plot
sns.boxplot(data=df_promo, x='category', y='discount', palette='pastel', ax=axes[1])
axes[1].set_title('Sebaran Diskon di Tiap Kategori Furnitur', fontsize=12, fontweight='bold')
axes[1].set_xlabel('Kategori')
axes[1].set_ylabel('Diskon')
axes[1].tick_params(axis='x', rotation=45) # Teks sumbu X dimiringin biar gak numpuk

plt.tight_layout()
plt.show()
