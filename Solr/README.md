## Loading data into Solr
### Using batch_loader.py
First, open the script and change the configuration variables at the top as necessary. Alternatively, use the `--solr-url` option to provide the Solr URL manually.

To load a batch from a directory into Solr:
```
./batch_loader.py index --batch-dir dir_path
```
The directory should have a `batch.json` file and data files ending in `.json`.

To load individual files into Solr:
```
./batch_loader.py index --file file_1 file2 file3
```
To delete a batch given its batch-type and batch-name:
```
./batch-loader.py delete --batch-type-name batch_type batch_name
```
To delete batches based on their batch-ids:
```
./batch_loader.py delete --batch-id batch_id_1 batch_id_2 batch_id_3
```
To delete individual documents based on their unique keys:
```
./batch_loader.py delete --doc-key unique_key_1 unique_key_2 unique_key_3
```
`batch_loader.py` automatically commits your changes after submitting them, so there's no need to send an extra commit command.

### Using curl
To load (index) a file named `data.json` into a core named `test-core` in a Solr instance running at `localhost` on port `8080`, do
```
curl http://localhost:8080/solr/test-core/update -H "Content-Type: text/json" --data-binary @data.json
```
The response on success should look something like
```
{
  "responseHeader":{
    "status":0,
    "QTime":28136}}
```
At this point the change has not yet been committed, so follow with a commit command:
```
curl http://localhost:8080/solr/test-core/update -H 'Content-type:text/xml; charset=utf-8' --data '<commit></commit>'
```
The commit command can also be combined with the update command by specifiying `commit=true` in the URL as a query parameter.