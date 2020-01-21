package org.eupathdb.sitesearchdata.model.report;

import static org.gusdb.fgputil.iterator.IteratorUtil.toStream;

import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.gusdb.fgputil.json.JsonWriter;
import org.gusdb.wdk.core.api.JsonKeys;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.answer.AnswerValue;
import org.gusdb.wdk.model.answer.stream.RecordStream;
import org.gusdb.wdk.model.answer.stream.RecordStreamFactory;
import org.gusdb.wdk.model.record.RecordInstance;
import org.gusdb.wdk.model.record.TableValue;
import org.gusdb.wdk.model.report.Reporter;
import org.gusdb.wdk.model.report.ReporterConfigException;
import org.gusdb.wdk.model.report.reporter.AnswerDetailsReporter;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Provides records returned by the answer value in the following JSON format:
 * [
 *   {
 *     "document-type": "gene",
 *     "primaryKey": ["pk1", "pk2", "pk3"],
 *     "id": "gene__pk1__pk1__pk3",
 *     "batch-type": "organism",
 *     "batch-name": "pfal3D7",
 *     "batch-timestamp": 123985030253
 *     "batch-id": "organism__pfal3D7__123985030253"
 *     "MULTITEXT__orthologs": [cell1, cell2...],
 *     "MUTLITEXT__aliases": [cell1, cell2...],
 *     "TEXT__product": "attribute value"
 *     etc.
 *   }
 * ]
 * 
 * we use the TABLE__ prefix to indicate to the solr schema that it is multivalued
 * 
 * Configuration includes these values beyond the standard json reporter config:
 * 
 * 
 * @author rdoherty, sfischer
 */
public class SolrLoaderReporter extends AnswerDetailsReporter {

  private String _batchType; // eg "organism"
  private int _batchTimestamp;
  private String _batchId;
  private String _batchName; // eg, "plasmodium falciparum 3d7"

  public static final String ATTR_PREFIX = "TEXT__";
  public static final String TABLE_PREFIX = "MULTITEXT__";
  
  public SolrLoaderReporter(AnswerValue answerValue) {
    super(answerValue);
  }
  
  @Override
  public Reporter configure(JSONObject config) throws ReporterConfigException, WdkModelException {
    List<String> configKeys = Arrays.asList("batch-type","batch-id","batch-name","batch-timestamp");
    if (!config.keySet().containsAll(configKeys))
        throw new ReporterConfigException("Config must include " + configKeys.toString());
    _batchName = config.getString("batch-name");
    _batchId = config.getString("batch-id");
    _batchType = config.getString("batch-type");
    _batchTimestamp = config.getInt("batch-timestamp");

    return super.configure(config);
  }

  @Override
  protected void write(OutputStream out) throws WdkModelException {

    // create output writer and initialize record stream
    try (JsonWriter writer = new JsonWriter(out);
         RecordStream records = RecordStreamFactory.getRecordStream(
            _baseAnswer, _attributes.values(), _tables.values())) {
      writer.array();
      for (RecordInstance record : records) {
        writer.value(formatRecord(record, _attributes.keySet(), _tables.keySet(), _batchType, _batchId, _batchName, _batchTimestamp));
      }
      writer.endArray();
    }
    catch (IOException e) {
      throw new WdkModelException("Unable to write reporter result to output stream", e);
    }
  }

  private static JSONObject formatRecord(RecordInstance record,
      Set<String> attributeNames, Set<String> tableNames, String batchType, String batchId, String batchName, int batchTimestamp) throws WdkModelException {
    try {
      Collection<String> pkValues = record.getPrimaryKey().getValues().values();
      String urlSegment = record.getRecordClass().getUrlSegment();
      Collection<String> idValues = new ArrayList<String>();
      idValues.add(urlSegment);
      idValues.addAll(pkValues);
      String idValuesString = idValues.stream().collect(Collectors.joining("__"));
      
      var obj = new JSONObject();
      obj.put("document-type", urlSegment);
      obj.put("primaryKey", pkValues); // multi string field. for forming record URLs
      obj.put("wdkPrimaryKeyString", String.join(",", pkValues)); // joined string field for sorting
      obj.put(JsonKeys.ID, idValuesString); // unique across all docs
      obj.put("batch-type", batchType);
      obj.put("batch-id", batchId);
      obj.put("batch-name", batchName);
      obj.put("batch-timestamp", batchTimestamp);
      for (String attributeName: attributeNames) {
        String name = record.getRecordClass().getAttributeFieldMap().get(attributeName).isInternal()?
              attributeName : ATTR_PREFIX + urlSegment + "_" + attributeName;
        obj.put(name, record.getAttributeValue(attributeName).getValue());
      }
      for (String tableName: tableNames) {
        String name = record.getRecordClass().getTableFieldMap().get(tableName).isInternal()?
            tableName : TABLE_PREFIX + urlSegment + "_" + tableName;
        obj.put(name, aggregateTableValueJson(record.getTableValue(tableName)));
      }
      return obj;
    }
    catch (Exception e) {
      throw WdkModelException.translateFrom(e);
    }
  }
  
  private static JSONArray aggregateTableValueJson(TableValue table) {
    JSONArray jsonarray = new JSONArray();
    toStream(table)
      .forEach(row -> row.values().stream()
        .forEach(cell -> {
          try {
            jsonarray.put(cell.getValue());
          }
          catch (WdkUserException | WdkModelException e) {
            throw new RuntimeException(e);
          }
        }));
    return jsonarray;
  }

}
