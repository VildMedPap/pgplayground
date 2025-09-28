#!/usr/bin/env python3
# /// script
# dependencies = [
#   "numpy>=1.26.0",
#   "psycopg2-binary>=2.9.9",
#   "python-dotenv>=1.0.0",
# ]
# ///

import os
import argparse

import numpy as np
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


def generate_random_vector(dimension=384):
    """Generate a random vector of specified dimension."""
    return np.random.rand(dimension).tolist()


def vector_to_string(vector):
    """Convert a vector to a PostgreSQL vector string format."""
    return f"[{','.join(map(str, vector))}]"


def insert_sample_data(num_samples=1_000):
    """Insert sample vector data into the database."""
    print(f"Inserting {num_samples} sample vectors...")

    # Connect to the database
    conn = psycopg2.connect(**conn_params)

    try:
        with conn.cursor() as cur:
            # Prepare data for batch insert
            data = []
            for i in range(num_samples):
                embedding_id = f"sample_{i + 1}"
                vector = generate_random_vector()
                vector_str = vector_to_string(vector)
                data.append((embedding_id, vector_str))

            # Use execute_values for efficient batch insertion
            execute_values(
                cur,
                "INSERT INTO embeddings (embedding_id, embedding) VALUES %s",
                data,
                template="(%s, %s::vector)",
            )

            conn.commit()
            print(f"Successfully inserted {num_samples} sample vectors.")

    except Exception as e:
        print(f"Error inserting vectors: {e}")
        conn.rollback()
    finally:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Insert simulated vectors into the database"
    )
    parser.add_argument(
        "--num-vectors",
        type=int,
        default=1000,
        help="Number of vectors to insert (default: 1000)",
    )
    args = parser.parse_args()

    insert_sample_data(args.num_vectors)
    print("Vector insertion completed successfully.")
