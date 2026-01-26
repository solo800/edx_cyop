#!/usr/bin/env python3
"""
Download, filter, and prepare DVF (Demandes de Valeurs Foncieres) dataset.
Filters to 4 target departments (Marseille, Toulouse, Bordeaux, Montpellier),
houses only, standard sales only.
"""

import os
import io
import zipfile
import requests
import pandas as pd
from pathlib import Path

# Data source URLs
DVF_URLS = {
    2020: "https://www.data.gouv.fr/api/1/datasets/r/4d741143-8331-4b59-95c2-3b24a7bdbe3c",
    2021: "https://www.data.gouv.fr/api/1/datasets/r/af812b0e-a898-4226-8cc8-5a570b257326",
    2022: "https://www.data.gouv.fr/api/1/datasets/r/cc8a50e4-c8d1-4ac2-8de2-c1e4b3c44c86",
    2023: "https://www.data.gouv.fr/api/1/datasets/r/8c8abe23-2a82-4b95-8174-1c1e0734c921",
    2024: "https://www.data.gouv.fr/api/1/datasets/r/e117fe7d-f7fb-4c52-8089-231e755d19d3",
    2025: "https://www.data.gouv.fr/api/1/datasets/r/8d771135-57c8-480f-a853-3d1d00ea0b69",
}

# Filter criteria
TARGET_DEPARTMENTS = ["13", "31", "33", "34"]  # Marseille, Toulouse, Bordeaux, Montpellier
TARGET_TYPE_LOCAL = "Maison"
TARGET_NATURE_MUTATION = "Vente"

# Output settings
OUTPUT_DIR = Path("data")
OUTPUT_FILE = OUTPUT_DIR / "dvf_filtered.csv.gz"
MAX_FILE_SIZE_MB = 100


def download_and_extract(url: str, year: int) -> pd.DataFrame:
    """Download zip file from URL and extract the CSV data."""
    print(f"Downloading {year} data...")
    response = requests.get(url, timeout=300)
    response.raise_for_status()

    print(f"Extracting {year} data...")
    with zipfile.ZipFile(io.BytesIO(response.content)) as zf:
        # Find the data file inside the zip
        data_files = [f for f in zf.namelist() if f.endswith('.txt') or f.endswith('.csv')]
        if not data_files:
            raise ValueError(f"No data file found in zip for year {year}")

        data_file = data_files[0]
        print(f"  Found file: {data_file}")

        with zf.open(data_file) as f:
            # Read pipe-delimited file
            df = pd.read_csv(
                f,
                sep='|',
                low_memory=False,
                dtype={'code_departement': str, 'code_postal': str, 'code_commune': str}
            )

    return df


def filter_data(df: pd.DataFrame, year: int) -> pd.DataFrame:
    """Apply filtering criteria to the dataframe."""
    print(f"Filtering {year} data...")
    initial_rows = len(df)

    # Ensure code_departement is string for comparison
    df['code_departement'] = df['code_departement'].astype(str).str.strip()

    # Apply filters
    mask = (
        (df['code_departement'].isin(TARGET_DEPARTMENTS)) &
        (df['type_local'] == TARGET_TYPE_LOCAL) &
        (df['nature_mutation'] == TARGET_NATURE_MUTATION)
    )

    filtered_df = df[mask].copy()
    final_rows = len(filtered_df)

    print(f"  {year}: {initial_rows:,} -> {final_rows:,} rows ({final_rows/initial_rows*100:.1f}% retained)")

    return filtered_df


def process_all_years() -> pd.DataFrame:
    """Download, filter, and combine all years of data."""
    all_data = []

    for year, url in DVF_URLS.items():
        try:
            df = download_and_extract(url, year)
            filtered_df = filter_data(df, year)
            filtered_df['year'] = year  # Add year column for reference
            all_data.append(filtered_df)
        except Exception as e:
            print(f"Error processing {year}: {e}")
            continue

    if not all_data:
        raise ValueError("No data was successfully processed")

    print("\nCombining all years...")
    combined_df = pd.concat(all_data, ignore_index=True)
    print(f"Total rows: {len(combined_df):,}")

    return combined_df


def save_data(df: pd.DataFrame) -> list[Path]:
    """Save the dataframe to compressed CSV, splitting if necessary."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # First, try saving as a single file
    print(f"\nSaving to {OUTPUT_FILE}...")
    df.to_csv(OUTPUT_FILE, index=False, compression='gzip')

    file_size_mb = OUTPUT_FILE.stat().st_size / (1024 * 1024)
    print(f"File size: {file_size_mb:.1f} MB")

    if file_size_mb <= MAX_FILE_SIZE_MB:
        print("File is under 100 MB - no splitting needed.")
        return [OUTPUT_FILE]

    # Need to split by year
    print(f"File is over {MAX_FILE_SIZE_MB} MB - splitting by year...")
    OUTPUT_FILE.unlink()  # Remove the combined file

    saved_files = []
    for year in df['year'].unique():
        year_df = df[df['year'] == year]
        year_file = OUTPUT_DIR / f"dvf_filtered_{year}.csv.gz"
        year_df.to_csv(year_file, index=False, compression='gzip')
        file_size = year_file.stat().st_size / (1024 * 1024)
        print(f"  {year_file.name}: {file_size:.1f} MB ({len(year_df):,} rows)")
        saved_files.append(year_file)

    return saved_files


def main():
    """Main entry point."""
    print("=" * 60)
    print("DVF Data Download and Filter Script")
    print("=" * 60)
    print(f"Target departments: {TARGET_DEPARTMENTS}")
    print(f"Type local: {TARGET_TYPE_LOCAL}")
    print(f"Nature mutation: {TARGET_NATURE_MUTATION}")
    print("=" * 60)

    # Process all years
    combined_df = process_all_years()

    # Show summary stats
    print("\n" + "=" * 60)
    print("Summary by Department:")
    print(combined_df.groupby('code_departement').size().to_string())
    print("\nSummary by Year:")
    print(combined_df.groupby('year').size().to_string())

    # Save the data
    saved_files = save_data(combined_df)

    print("\n" + "=" * 60)
    print("Done! Files saved:")
    for f in saved_files:
        print(f"  - {f}")
    print("=" * 60)

    return saved_files


if __name__ == "__main__":
    main()
