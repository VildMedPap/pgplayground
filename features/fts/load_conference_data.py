#!/usr/bin/env python3
# /// script
# dependencies = [
#   "beautifulsoup4>=4.12.0",
#   "lxml>=4.9.0",
#   "psycopg2-binary>=2.9.9",
#   "python-dotenv>=1.0.0",
#   "ujson>=5.10.0",
# ]
# ///
"""
Parse the PGConfEU 2025 schedule XML and load it into PostgreSQL.
"""

import os
import re
import sys
from datetime import datetime
from pathlib import Path

import psycopg2
import ujson as json
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from lxml import etree
from psycopg2.extras import execute_values

# Load environment variables
load_dotenv("../../.env")

# Database connection parameters
conn_params = {
    "dbname": "testdb",  # Using the main database with ICU collation
    "user": os.getenv("DB_USER", "testuser"),
    "password": os.getenv("DB_PASSWORD", "testpassword"),
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 5432)),
}


def clean_html(text):
    """Remove HTML tags and clean up text using BeautifulSoup."""
    if not text:
        return ""

    # Use BeautifulSoup to properly parse and extract text
    soup = BeautifulSoup(text, 'html.parser')

    # Extract text from HTML
    clean = soup.get_text()

    # Clean up whitespace
    clean = re.sub(r'\s+', ' ', clean)
    clean = clean.strip()

    return clean


def parse_schedule_xml(xml_file):
    """Parse the schedule XML file and extract event data."""
    events = []

    try:
        # Parse the XML file
        tree = etree.parse(xml_file)
        root = tree.getroot()

        # Get conference metadata
        conference = root.find("conference")
        if conference is None:
            print("Warning: No conference element found in XML")
            return events

        conf_title = conference.findtext("title", "")
        conf_start = conference.findtext("start", "")
        conf_end = conference.findtext("end", "")

        print(f"Parsing schedule for: {conf_title}")
        print(f"Conference dates: {conf_start} to {conf_end}")

        # Parse each day
        for day in root.findall(".//day"):
            day_date = day.get("date", "")

            # Parse each room in the day
            for room in day.findall("room"):
                room_name = room.get("name", "")

                # Parse each event in the room
                for event in room.findall("event"):
                    event_id = event.get("id")
                    if not event_id:
                        continue

                    # Extract event data and clean HTML
                    title = clean_html(event.findtext("title", ""))
                    abstract = clean_html(event.findtext("abstract", ""))
                    url = event.findtext("url", "")  # URLs don't need HTML cleaning
                    track = clean_html(event.findtext("track", ""))

                    # Remove duration from track names (e.g., "DBA (45 minutes)" -> "DBA")
                    if track:
                        track = re.sub(r'\s*\(\d+\s*minutes?\)', '', track).strip()
                    start_time_str = event.findtext("start", "")
                    duration_str = event.findtext("duration", "00:00")

                    # Parse speakers and clean HTML
                    speakers_list = []
                    persons = event.find("persons")
                    if persons is not None:
                        for person in persons.findall("person"):
                            name = person.text
                            if name:
                                speakers_list.append(clean_html(name))
                    speakers = ", ".join(speakers_list)

                    # Parse start time
                    start_time = None
                    if start_time_str and day_date:
                        try:
                            # Combine date and time
                            datetime_str = f"{day_date} {start_time_str}"
                            start_time = datetime.strptime(
                                datetime_str, "%Y-%m-%d %H:%M"
                            )
                        except ValueError:
                            print(f"Warning: Could not parse datetime: {datetime_str}")

                    # Parse duration (format: HH:MM)
                    duration_minutes = 0
                    if duration_str and ":" in duration_str:
                        try:
                            hours, minutes = duration_str.split(":")
                            duration_minutes = int(hours) * 60 + int(minutes)
                        except ValueError:
                            print(f"Warning: Could not parse duration: {duration_str}")

                    # Additional metadata
                    metadata = {
                        "day": day_date,
                        "conference_title": conf_title,
                        "conference_start": conf_start,
                        "conference_end": conf_end,
                    }

                    # Add type if present
                    event_type = event.findtext("type", "")
                    if event_type:
                        metadata["type"] = event_type

                    # Add language if present
                    language = event.findtext("language", "")
                    if language:
                        metadata["language"] = language

                    # Skip break events
                    if track and track.lower() == 'breaks':
                        continue

                    # Clean and prepare data
                    event_data = {
                        "event_id": int(event_id),
                        "title": title.strip() if title else "",
                        "abstract": abstract.strip() if abstract else "",
                        "speakers": speakers,
                        "url": url.strip() if url else "",
                        "room": room_name,
                        "track": track.strip() if track else "",
                        "duration": duration_minutes,
                        "start_time": start_time,
                        "metadata": json.dumps(metadata),
                    }

                    events.append(event_data)

        print(f"✓ Parsed {len(events)} events from XML")
        return events

    except etree.XMLSyntaxError as e:
        print(f"✗ XML parsing error: {e}", file=sys.stderr)
        return []
    except Exception as e:
        print(f"✗ Unexpected error parsing XML: {e}", file=sys.stderr)
        return []


def load_events_to_database(events):
    """Load parsed events into PostgreSQL database."""
    if not events:
        print("No events to load")
        return False

    conn = None
    try:
        # Connect to database
        print(f"Connecting to database: {conn_params['dbname']}")
        conn = psycopg2.connect(**conn_params)
        conn.autocommit = False
        cur = conn.cursor()

        # Clear existing data
        print("Clearing existing conference data...")
        cur.execute("TRUNCATE TABLE conference_events RESTART IDENTITY CASCADE")

        # Prepare data for bulk insert
        insert_data = [
            (
                event["event_id"],
                event["title"],
                event["abstract"],
                event["speakers"],
                event["url"],
                event["room"],
                event["track"],
                event["duration"],
                event["start_time"],
                event["metadata"],
            )
            for event in events
        ]

        # Bulk insert using execute_values (much faster than individual inserts)
        print(f"Loading {len(events)} events into database...")
        insert_query = """
            INSERT INTO conference_events (
                event_id, title, abstract, speakers, url,
                room, track, duration, start_time, metadata
            ) VALUES %s
            ON CONFLICT (event_id) DO UPDATE SET
                title = EXCLUDED.title,
                abstract = EXCLUDED.abstract,
                speakers = EXCLUDED.speakers,
                url = EXCLUDED.url,
                room = EXCLUDED.room,
                track = EXCLUDED.track,
                duration = EXCLUDED.duration,
                start_time = EXCLUDED.start_time,
                metadata = EXCLUDED.metadata
        """

        execute_values(
            cur,
            insert_query,
            insert_data,
            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)",
            page_size=100,
        )

        # Commit the transaction
        conn.commit()

        # Verify the load
        cur.execute("SELECT COUNT(*) FROM conference_events")
        count = cur.fetchone()[0]
        print(f"✓ Successfully loaded {count} events into database")

        # Show sample of loaded data
        cur.execute(
            """
            SELECT title, track, room, speakers
            FROM conference_events
            WHERE title != ''
            LIMIT 5
        """
        )
        print("\nSample of loaded events:")
        for row in cur.fetchall():
            title, track, room, speakers = row
            print(f"  - {title[:50]}... [{track}] in {room}")
            if speakers:
                print(f"    Speakers: {speakers[:60]}")

        # Update table statistics for query optimizer
        print("\nUpdating table statistics...")
        cur.execute("ANALYZE conference_events")
        conn.commit()

        return True

    except psycopg2.Error as e:
        print(f"✗ Database error: {e}", file=sys.stderr)
        if conn:
            conn.rollback()
        return False
    except Exception as e:
        print(f"✗ Unexpected error: {e}", file=sys.stderr)
        if conn:
            conn.rollback()
        return False
    finally:
        if conn:
            conn.close()


def main():
    """Main function to parse XML and load data."""
    xml_file = Path("data/schedule.xml")

    # Check if XML file exists
    if not xml_file.exists():
        print(f"✗ Error: Schedule file not found at {xml_file}")
        print("  Run 'make download-schedule' first")
        return False

    # Parse the XML file
    print("=" * 60)
    print("Parsing conference schedule...")
    print("=" * 60)
    events = parse_schedule_xml(xml_file)

    if not events:
        print("✗ No events parsed from XML")
        return False

    # Load events into database
    print("\n" + "=" * 60)
    print("Loading data into PostgreSQL...")
    print("=" * 60)
    success = load_events_to_database(events)

    if success:
        print("\n" + "=" * 60)
        print("✓ Data loading complete!")
        print("  You can now run 'make test-fts' to test FTS queries")
        print("=" * 60)

    return success


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)