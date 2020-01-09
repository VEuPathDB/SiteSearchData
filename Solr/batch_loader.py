#!/usr/bin/python3

import argparse
import json
import os
import traceback
import requests

# Configuration
HOST = 'http://localhost:8983'
CORE = 'test-core'
BATCH_ID_FIELD = 'batch-id'
UNIQUE_KEY_FIELD = 'id'

# TODO move these out to environment variables
USER = ''
PASS = ''

AUTH = (USER, PASS)

# Parse the arguments
def parse_args():
    parser = argparse.ArgumentParser(description='Add, update, or remove batches or individual files from Solr\'s index. Configuration variables are located at the beginning of the script.')

    parser.add_argument('--solr-url', help='The URL of the Solr instance, including core, but not including operation (ex: http://localhost:8080/solr/test-core). If not provided, the configuration variables at the beginning of the script will be used.')
    parser.add_argument('--production', action='store_true', help='Make changes to the production core rather than the QA core (not currently functional).')

    subparsers = parser.add_subparsers(title='subcommands', help='Add a subcommand name followed by -h for specific help on it.')

    # Index subparser
    parser_index = subparsers.add_parser('index', help='Index files or batches into Solr.')
    parser_index.set_defaults(func=index)
    parser_index.add_argument('--batch-dir', help='Index a batch contained in the given directory. The directory should contain a batch.json file and the .json files containing the data. The JSON files should adhere to the requirements listed in the --file option. The data files will be loaded first, and batch.json last, indicating a successful load.')
    parser_index.add_argument('--file', nargs='+', metavar='FILE', dest='file_paths', help='Index individual files. Each file must be a JSON-formatted list of Solr documents, that is, a JSON array containing JSON objects.')

    # Delete subparser
    parser_delete = subparsers.add_parser('delete', help='Delete documents or batches from Solr.')
    parser_delete.set_defaults(func=delete)
    parser_delete.add_argument('--batch-type-name', nargs=2, metavar=('BATCH_TYPE', 'BATCH_NAME'), help='Delete a batch of documents with the given batch type and batch name. Provide the batch type followed by the batch name, separated by a space (ex: --batch-type-name organism pberANKA).')
    parser_delete.add_argument('--batch-id', nargs='+', metavar='BATCH_ID', dest='batch_ids', help='Delete a batch of documents by batch ID.')
    parser_delete.add_argument('--doc-key', nargs='+', metavar='UNIQUE_KEY', dest='doc_keys', help='Delete documents by unique key.')

    # Rollback subparser
    parser_rollback = subparsers.add_parser('rollback', help='Rollback any staged changes in Solr.')
    parser_rollback.set_defaults(func=rollback)

    args = parser.parse_args()
    return args

# A wrapper for running commands
def run(kwargs):
    # Remove and store arguments that don't get passed to func.
    func = kwargs['func']
    del kwargs['func']

    # If the URL wasn't provided from the command line, build it from the config variables
    if not kwargs['solr_url']:
        kwargs['solr_url'] = HOST + '/solr/' + CORE

    update_url = kwargs['solr_url'] + '/update'

    # If func is rollback, just do it
    if func is rollback:
        func(update_url)

    # Otherwise, execute func with safeguards
    else:
        action_taken = False

        try:
            # Run the command
            action_taken = func(**kwargs)

            # If we did something, commit the changes
            if action_taken:
                print('Committing changes')
                solr_request('POST', update_url, data='<commit/>', auth=AUTH, headers={'content-type':'application/xml'})
                print('Changes committed')
        
            else:
                print("No action. Add '-h' for help")

        # If we encouter an error, attempt to roll back
        except Exception as e:
            print(traceback.format_exc())

            try:
                rollback(update_url)
                print('An error occurred and changes were rolled back.')

            except Exception as e:
                print(traceback.format_exc())
                print('An error occurred, but rollback failed. Changes could still be staged in Solr.')

            finally:
                exit(1)

# Index files or batches
def index(solr_url, batch_dir=None, file_paths=None, production=False):
    update_url = solr_url + '/update'
    select_url = solr_url + '/select'
    batch_json_path = batch_dir + '/batch.json'
    action_taken = False

    if batch_dir:
        try:
            with open(batch_json_path) as batch_json_file:
                batch_json = json.load(batch_json_file)[0]
        except FileNotFoundError:
            print('Error: batch.json not found in ' + batch_dir)
            raise

        batch_type = batch_json['batch-type']
        batch_name = batch_json['batch-name']

        # Check to see whether the batch already exists in Solr
        url = select_url + '?q=batch-type:{} AND batch-name:{}&rows=0'.format(batch_type, batch_name)
        print("Checking for the absence of batch '{} {}' in Solr".format(batch_type, batch_name))
        response = solr_request('GET', url, auth=AUTH)

        if response.json()['response']['numFound']:
            print("Error: Documents with batch-type '{}' and batch-name '{}' already exist in Solr. Delete the existing documents before loading this batch.".format(batch_type, batch_name))
        else:
            # Get all file objects in the directory
            dir_files = [obj for obj in os.scandir(batch_dir) if obj.is_file()]

            # Index all data files
            for file_obj in dir_files:
                if file_obj.name.endswith('.json') and file_obj.name != 'batch.json':
                    index_file(file_obj, update_url)
                    action_taken = True

            # Finally, index batch.json
            index_file(batch_json_path, update_url)
            action_taken = True

    # If there are new files to index, index them
    if file_paths:
        for path in file_paths:
            index_file(path, update_url)
            action_taken = True

    return action_taken

# Delete documents or batches
def delete(solr_url, batch_type_name=None, batch_ids=None, doc_keys=None, production=False):
    url = solr_url + '/update'
    action_taken = False

    if batch_type_name:
        batch_type, batch_name = batch_type_name

        print("Deleting batch '{} {}'".format(batch_type, batch_name))
        data = '<delete><query>batch-type:{} AND batch-name:{}</query></delete>'.format(batch_type, batch_name)
        solr_request('POST', url, data=data, auth=AUTH, headers={'content-type':'application/xml'})
        action_taken = True

    # If there is a del_batch_id, use it to delete the old batch
    if batch_ids:
        for batch_id in batch_ids:
            print('Deleting batch ' + batch_id)
            data = '<delete><query>{}:{}</query></delete>'.format(BATCH_ID_FIELD, batch_id)
            solr_request('POST', url, data=data, auth=AUTH, headers={'content-type':'application/xml'})
            action_taken = True

    # If there is a del_key, use it to delete documents
    if doc_keys:
        for key in doc_keys:
            print('Deleting document with key ' + key)
            data = '<delete><query>{}:{}</query></delete>'.format(UNIQUE_KEY_FIELD, key)
            solr_request('POST', url, data=data, auth=AUTH, headers={'content-type':'application/xml'})
            action_taken = True

    return action_taken

# Roll back changes
def rollback(url):
    print('Rolling back changes')

    try:
        solr_request('POST', url, data='<rollback/>', auth=AUTH, headers={'content-type':'application/xml'})
        print('Rollback successful')

    except Exception as e:
        print('Error: Unable to roll back changes')
        raise

# Index a file
def index_file(path_like, url):
    with open(path_like) as f:
        print('Indexing file ' + f.name)
        data = f.read()
        solr_request('POST', url, data=data, auth=AUTH, headers={'content-type':'application/json'})

# Make a request to Solr, print its response, and raise an error if necessary
def solr_request(method, url, data=None, auth=None, headers=None):
    if data:
        data = data.encode('utf-8')

    request = requests.request(method, url, data=data, auth=auth, headers=headers)

    print('Solr response:')
    print(request.text)
    request.raise_for_status()

    return request

if __name__ == '__main__':
    kwargs = vars(parse_args())
    run(kwargs)
