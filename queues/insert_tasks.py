import argparse
import os
import random
import string

import psycopg2
import ujson as json
from dotenv import load_dotenv

load_dotenv("../.env")

conn_params = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": int(os.getenv("DB_PORT", 5432)),
}


def generate_random_payload(task_number):
    """Generate a random task payload with some variability."""
    # Create random string data to simulate variable task content
    random_data = "".join(random.choices(string.ascii_letters + string.digits, k=10))

    # Generate random processing time between 5-15 seconds
    processing_time = random.randint(1, 5)

    return {
        "task_number": task_number,
        "data": f"Task data {random_data}",
        "processing_time": processing_time,
    }


def insert_tasks(num_tasks):
    """Insert tasks into the database.

    Args:
        num_tasks (int): Number of tasks to insert
    """
    conn = psycopg2.connect(**conn_params)

    try:
        with conn.cursor() as cur:
            for i in range(1, num_tasks + 1):
                # Generate payload with random data and processing time
                payload = generate_random_payload(i)

                # Store the suggested processing time in a dedicated column for easy querying
                cur.execute(
                    """
                    INSERT INTO tasks (payload, processing_time) 
                    VALUES (%s, %s) 
                    RETURNING id
                """,
                    (json.dumps(payload), payload["processing_time"]),
                )

                task_id = cur.fetchone()[0]
                print(
                    f"Added task {task_id} with processing time {payload['processing_time']} seconds"
                )

        conn.commit()
        print(f"✓ Successfully inserted {num_tasks} tasks")

    except Exception as e:
        conn.rollback()
        print(f"Error inserting tasks: {e}")

    finally:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Insert tasks into the database")
    parser.add_argument(
        "--num-tasks",
        type=int,
        default=30,
        help="Number of tasks to insert (default: 30)",
    )
    args = parser.parse_args()

    insert_tasks(args.num_tasks)
