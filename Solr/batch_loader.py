#!/usr/bin/python3

import argparse
import json
import requests

# Configuration
HOST = 'http://localhost:8080'
CORE = 'test-core'
BATCH_ID_FIELD = 'batch-id'
UNIQUE_KEY_FIELD = 'id'

# TODO move these out to environment variables
USER = ''
PASS = ''

# Parse the arguments
def parse_args():
    parser = argparse.ArgumentParser(description='Add, update, or remove batches or individual files from Solr\'s index. Configuration variables are located at the beginning of the script.')

    parser.add_argument('--index', nargs='+', metavar='FILE', help='Index files. Each file must be a JSON-formatted list of Solr documents, that is, a JSON array containing JSON objects. If the file is just a single JSON object not in an array, indexing will fail.')
    parser.add_argument('--delete-batch', nargs='+', metavar='BATCH_ID', help='Delete a batch of documents by batch ID')
    parser.add_argument('--delete-doc', nargs='+', metavar='UNIQUE_KEY', help='Delete documents by unique key')
    parser.add_argument('--production', action='store_true', help='Make changes to the production core as well the QA core (not currently functional)')

    args = parser.parse_args()
    return args

# Index or delete files
def index(del_batch_ids, del_keys, file_paths, production=False):
    url = HOST + '/solr/' + CORE + '/update'
    auth = (USER, PASS)
    action_taken = False

    # Try to make the requested changes
    try:
        # If there is a del_batch_id, use it to delete the old batch
        if del_batch_ids:
            for batch_id in del_batch_ids:
                print('Deleting batch ' + batch_id)
                data = '<delete><query>{}:{}</query></delete>'.format(BATCH_ID_FIELD, batch_id)
                solr_request('POST', url, data=data, auth=auth, headers={'content-type':'application/xml'})
                action_taken = True

        # If there is a del_key, use it to delete documents
        if del_keys:
            for key in del_keys:
                print('Deleting document with key ' + key)
                data = '<delete><query>{}:{}</query></delete>'.format(UNIQUE_KEY_FIELD, key)
                solr_request('POST', url, data=data, auth=auth, headers={'content-type':'application/xml'})
                action_taken = True
    
        # If there are new files to index, index them
        if file_paths:
            for file_path in file_paths:
                with open(file_path) as f:
                    print('Indexing file ' + file_path)
                    data = f.read()
                    solr_request('POST', url, data=data, auth=auth, headers={'content-type':'application/json'})
                    action_taken = True
    
        # If we did something, commit the changes
        if action_taken:
            print('Committing changes')
            solr_request('POST', url, data='<commit/>', auth=auth, headers={'content-type':'application/xml'})
            print('Changes committed')
    
        else:
            print("No action. Add '-h' for help")

    # If we encouter an error and we made changes, attempt to roll back the changes
    except requests.HTTPError as e:
        print(e)

        if action_taken:
            try:
                print('Rolling back changes')
                solr_request('POST', url, data='<rollback/>', auth=auth, headers={'content-type':'application/xml'})
                print('Error encountered. Changes rolled back')

            except requests.HTTPError:
                print('Warning: An error was encountered, and we could not roll back changes')

# Make a request to Solr, print its response, and raise an error if necessary
def solr_request(method, url, data=None, auth=None, headers=None):
    data = data.encode('utf-8')
    request = requests.request(method, url, data=data, auth=auth, headers=headers)

    print('Solr response:')
    print(request.text)
    request.raise_for_status()

    return request

if __name__ == '__main__':
   args = parse_args()
   index(args.delete_batch, args.delete_doc, args.index, args.production)

