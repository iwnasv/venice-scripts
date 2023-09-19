#!/usr/bin/env python3
import argparse
import psycopg2

query_conditions = "FROM cwf_pooltask as p_task " \
                   "JOIN cwf_workflowitem as w_item ON w_item.workflowitem_id = p_task.workflowitem_id " \
                   "JOIN metadatavalue as identifier ON identifier.dspace_object_id = w_item.item_id " \
                   "AND metadata_field_id = 24 " \
                   "WHERE identifier.text_value {} %s "

def connect_to_database():
    return psycopg2.connect(
        user="dspace",
        password="dspace",
        host="127.0.0.1",
        port="5432",
        database="dspace"
    )

def get_task_count(pattern, cursor, equal=False):
    condition = "=" if equal else "LIKE"
    count_query = "SELECT COUNT(*) " + query_conditions.format(condition)

    cursor.execute(count_query, (pattern,))
    count = cursor.fetchone()[0]

    return count

parser = argparse.ArgumentParser()
parser.add_argument("identifier_pattern", help="Pattern to search for in task identifiers")
parser.add_argument("-e", "--equal", action="store_true", help="Toggle EQUAL query instead of LIKE")
args = parser.parse_args()

identifier_pattern = args.identifier_pattern
use_equal = args.equal

connection = None
cursor = None

try:
    connection = connect_to_database()
    cursor = connection.cursor()

    task_count = get_task_count(identifier_pattern, cursor, use_equal)
    print(task_count)

except psycopg2.Error as error:
    print("Error fetching data from PostgreSQL table:", error)

finally:
    # Closing database connection
    if cursor:
        cursor.close()

    if connection:
        connection.close()
