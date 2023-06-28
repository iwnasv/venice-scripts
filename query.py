import argparse
import psycopg2
import sys

query_conditions = "FROM cwf_pooltask as p_task " \
                   "JOIN cwf_workflowitem as w_item ON w_item.workflowitem_id = p_task.workflowitem_id " \
                   "JOIN metadatavalue as identifier ON identifier.dspace_object_id = w_item.item_id " \
                   "AND metadata_field_id = 24 " \
                   "WHERE identifier.text_value LIKE %s "

def connect_to_database():
    return psycopg2.connect(
        user="dspace",
        password="dspace",
        host="127.0.0.1",
        port="5432",
        database="dspace"
    )

def get_task_count(pattern, cursor):
    count_query = "SELECT COUNT(*) " + query_conditions

    cursor.execute(count_query, (pattern,))
    count = cursor.fetchone()[0]

    return count

def get_task_identifiers(pattern, cursor, assigned_to=False):
    if assigned_to:
        fetch_query = "SELECT p_task.pooltask_id, identifier.text_value, e.email " + query_conditions + \
                    "JOIN eperson as e ON e.eperson_id = p_task.eperson_id"

    else:
        fetch_query = "SELECT p_task.pooltask_id, identifier.text_value " + query_conditions

    cursor.execute(fetch_query, (pattern,))

    result = cursor.fetchall()

    if assigned_to:
        task_identifiers = [(task_id, identifier, assigned_uuid) for task_id, identifier, assigned_uuid in result]
    else:
        task_identifiers = [(task_id, identifier) for task_id, identifier in result]

    return task_identifiers

parser = argparse.ArgumentParser()
parser.add_argument("identifier_pattern", help="Pattern to search for in task identifiers")
parser.add_argument("--list-tasks", action="store_true", help="List the task identifiers")
parser.add_argument("--assignedto", action="store_true", help="Print assigned UUID with tasks")
args = parser.parse_args()

identifier_pattern = args.identifier_pattern
list_tasks = args.list_tasks
assigned_to = args.assignedto

connection = None
cursor = None

try:
    connection = connect_to_database()
    cursor = connection.cursor()

    task_count = get_task_count(identifier_pattern, cursor)

    if list_tasks:
        task_identifiers = get_task_identifiers(identifier_pattern, cursor, assigned_to)
        if assigned_to:
            for task_id, identifier, assigned_uuid in task_identifiers:
                print(f"{task_id},{assigned_uuid}")
        else:
            for task_id, identifier in task_identifiers:
                print(task_id)
    else:
        print(task_count)

except psycopg2.Error as error:
    print("Error fetching data from PostgreSQL table", error)

except Exception as error:
    print("Other error: ", error)

finally:
    # Closing database connection
    if cursor:
        cursor.close()

    if connection:
        connection.close()
