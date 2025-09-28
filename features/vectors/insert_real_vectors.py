#!/usr/bin/env python3
# /// script
# dependencies = [
#   "pandas>=2.2.3",
#   "psycopg2-binary>=2.9.9",
#   "python-dotenv>=1.0.0",
# ]
# ///

import os

import pandas as pd
import psycopg2
from dotenv import load_dotenv
from psycopg2.extras import execute_values

load_dotenv("../../.env")

conn_params = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": int(os.getenv("DB_PORT", 5432)),
}

# CSV file path
CSV_FILE = "data/real_embeddings.csv"


def insert_vectors_from_csv(batch_size=1000):
    """Insert vectors from CSV file into the database in batches."""
    print(f"Loading vectors from {CSV_FILE}...")

    # Connect to the database
    conn = psycopg2.connect(**conn_params)

    try:
        with conn.cursor() as cur:
            # Process the CSV file in chunks to handle large files efficiently
            total_rows = 0
            batch_count = 0

            # Use pandas to read the CSV file in chunks
            for chunk in pd.read_csv(CSV_FILE, chunksize=batch_size):
                # Prepare data for batch insert
                data = []
                for _, row in chunk.iterrows():
                    embedding_id = row["EMBEDDING_ID"]
                    # The embedding is already in the correct format as a string
                    embedding = row["EMBEDDING"]
                    data.append((embedding_id, embedding))

                # Use execute_values for efficient batch insertion
                execute_values(
                    cur,
                    "INSERT INTO embeddings (embedding_id, embedding) VALUES %s",
                    data,
                    template="(%s, %s::vector)",
                )

                total_rows += len(data)
                batch_count += 1

                # Commit after each batch
                conn.commit()
                print(f"Inserted batch {batch_count} ({total_rows} rows so far)")

            print(f"Successfully inserted {total_rows} vectors from CSV.")

    except Exception as e:
        print(f"Error inserting vectors: {e}")
        conn.rollback()
    finally:
        conn.close()


if __name__ == "__main__":
    insert_vectors_from_csv()
    print("Vector insertion from CSV completed successfully.")
