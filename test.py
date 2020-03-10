import subprocess
output = subprocess.getoutput("tail -c 1 /eupath/data/EuPathDB/siteSearchDataDumps/bld47/PlasmoDB/solr-json-batch_pathway_PlasmoDB_1583438485/batch.json")
if output != ' ':
  print("ERROR")
else:
  print("OK")

