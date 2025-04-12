import os
import time
import uuid

import psycopg2
from dotenv import load_dotenv

load_dotenv("../.env")

conn_params = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": int(os.getenv("DB_PORT", 5432)),
}


def process_next_task(worker_id):
    """Claim and process a single task from the queue using FOR UPDATE SKIP LOCKED."""
    conn = psycopg2.connect(**conn_params)

    # Turn off autocommit to manage the transaction manually
    conn.autocommit = False

    try:
        with conn.cursor() as cur:
            # The key query that grabs an available task and locks it
            # FOR UPDATE locks the row so other transactions cannot modify it
            # SKIP LOCKED means if a row is already locked, skip it and find another
            cur.execute("""
                SELECT id, payload, processing_time 
                FROM tasks 
                WHERE status = 'pending' 
                ORDER BY created_at 
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            """)

            # Check if we found an available task
            task = cur.fetchone()
            if task is None:
                print(f"Worker {worker_id}: No pending tasks available")
                conn.rollback()
                return False

            # Extract task details
            task_id, payload, processing_time = task

            # No need to decode or parse the payload as psycopg2 already converts JSONB to Python dict
            # Just use the payload directly

            # Mark the task as processing and record which worker claimed it
            print(f"Worker {worker_id}: Claiming task {task_id}")
            cur.execute(
                """
                UPDATE tasks 
                SET status = 'processing', 
                    updated_at = NOW(),
                    worker_id = %s
                WHERE id = %s
            """,
                (worker_id, task_id),
            )

            # Commit the transaction to release the lock but keep the status updated
            # This lets us see the task as "processing" in DBeaver
            conn.commit()

            # Start a new transaction for the actual processing
            conn.autocommit = False

            # Simulate the task processing with the suggested processing time
            print(
                f"Worker {worker_id}: Processing task {task_id} (will take {processing_time} seconds)..."
            )
            time.sleep(processing_time)  # This gives you time to observe in DBeaver

            # Mark the task as completed
            cur.execute(
                """
                UPDATE tasks 
                SET status = 'completed', 
                    processed_at = NOW(), 
                    updated_at = NOW() 
                WHERE id = %s
            """,
                (task_id,),
            )

            # Commit the completion
            conn.commit()
            print(f"Worker {worker_id}: Completed task {task_id}")
            return True

    except Exception as e:
        # If anything goes wrong, roll back and mark the task as failed
        print(f"Worker {worker_id}: Error processing task: {e}")

        try:
            # Only attempt to update if we have a task_id from earlier in the function
            if "task_id" in locals():
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        UPDATE tasks 
                        SET status = 'failed', 
                            updated_at = NOW() 
                        WHERE id = %s
                    """,
                        (task_id,),
                    )
                    conn.commit()
            else:
                conn.rollback()
        except Exception as inner_e:
            print(f"Worker {worker_id}: Could not mark task as failed: {inner_e}")
            conn.rollback()

        return False

    finally:
        conn.close()


def worker_loop(worker_id):
    """Keep processing tasks until there are none left."""
    tasks_processed = 0

    print(f"Worker {worker_id}: Starting task processing")

    while True:
        # Process a single task
        success = process_next_task(worker_id)

        # If no tasks were available, we're done
        if not success:
            if tasks_processed == 0:
                print(f"Worker {worker_id}: No tasks were available to process")
            else:
                print(
                    f"Worker {worker_id}: Finished processing {tasks_processed} tasks"
                )
            break

        tasks_processed += 1

        # Small pause between task processing to simulate a real worker
        time.sleep(0.5)

    return tasks_processed


if __name__ == "__main__":
    # Generate a unique worker ID so we can identify different processes
    worker_id = str(uuid.uuid4())[:8]

    # Start the worker loop
    total_processed = worker_loop(worker_id)

    print(f"Worker {worker_id}: Processed {total_processed} tasks in total")
