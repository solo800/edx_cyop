"""
Sales Volume by Year: City Proper vs Suburbs for each Commune Group
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

# Load the clean house sales data
df = pd.read_csv('/Users/adamsolomon/app-construction/cyo_edx/data/dvf_houses_clean.csv')

# Map ring to readable labels
df['area_type'] = df['ring'].map({0: 'City Proper', 1: 'Suburbs'})

# Aggregate: count sales by city, area_type, year
volume = (
    df.groupby(['target_city', 'area_type', 'year'])
    .size()
    .reset_index(name='sales')
)

# City color palette (matching the R script, south → north + benchmark)
city_colors = {
    'Marseille':   '#E63946',
    'Montpellier': '#F4A261',
    'Toulouse':    '#E9C46A',
    'Lyon':        '#2A9D8F',
    'Annecy':      '#264653',
    'Bordeaux':    '#6A4C93',
    'Paris':       '#457B9D',
}

# Ordered city list (south → north + Paris benchmark)
city_order = ['Marseille', 'Montpellier', 'Toulouse', 'Lyon', 'Annecy', 'Bordeaux', 'Paris']
years = sorted(df['year'].unique())

# --- Build the figure: 7 subplots (one per city), 2 columns layout ---
fig, axes = plt.subplots(4, 2, figsize=(14, 18), sharey=False)
axes = axes.flatten()

bar_width = 0.35

for idx, city in enumerate(city_order):
    ax = axes[idx]
    city_data = volume[volume['target_city'] == city]

    city_proper = city_data[city_data['area_type'] == 'City Proper'].set_index('year')['sales']
    suburbs = city_data[city_data['area_type'] == 'Suburbs'].set_index('year')['sales']

    # Ensure all years present
    city_vals = [city_proper.get(y, 0) for y in years]
    suburb_vals = [suburbs.get(y, 0) for y in years]

    x = np.arange(len(years))

    base_color = city_colors[city]
    # Lighter version for suburbs
    from matplotlib.colors import to_rgba
    suburb_color = to_rgba(base_color, alpha=0.50)

    bars1 = ax.bar(x - bar_width/2, city_vals, bar_width, label='City Proper (Ring 0)',
                   color=base_color, edgecolor='white', linewidth=0.5)
    bars2 = ax.bar(x + bar_width/2, suburb_vals, bar_width, label='Suburbs (Ring 1)',
                   color=suburb_color, edgecolor='white', linewidth=0.5)

    # Value labels on bars
    for bar in bars1:
        h = bar.get_height()
        if h > 0:
            ax.text(bar.get_x() + bar.get_width()/2, h + 15, f'{int(h):,}',
                    ha='center', va='bottom', fontsize=7, fontweight='bold', color='#333')
    for bar in bars2:
        h = bar.get_height()
        if h > 0:
            ax.text(bar.get_x() + bar.get_width()/2, h + 15, f'{int(h):,}',
                    ha='center', va='bottom', fontsize=7, color='#555')

    ax.set_title(city, fontsize=14, fontweight='bold', color=base_color, pad=10)
    ax.set_xticks(x)
    ax.set_xticklabels(years, fontsize=9)
    ax.set_ylabel('Number of Sales', fontsize=9)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f'{int(v):,}'))
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', alpha=0.3, linestyle='--')

    # Add legend only to first subplot
    if idx == 0:
        ax.legend(fontsize=8, loc='upper right')

# Hide the 8th (empty) subplot
axes[7].set_visible(False)

# Add a note about 2020 being H2-only
fig.text(0.5, 0.01,
         'Note: 2020 contains only H2 data (July–December). Source: DVF open data, 59,373 cleaned house transactions.',
         ha='center', fontsize=9, color='#666', style='italic')

fig.suptitle('House Sales Volume by Year\nCity Proper vs. Surrounding Suburbs',
             fontsize=18, fontweight='bold', y=0.98)

plt.tight_layout(rect=[0, 0.03, 1, 0.95])

output_path = '/Users/adamsolomon/app-construction/cyo_edx/reports/sales_volume_city_vs_suburbs.png'
fig.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='white')
print(f"Saved to: {output_path}")
plt.show()
