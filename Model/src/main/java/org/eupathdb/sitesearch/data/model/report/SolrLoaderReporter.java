package org.eupathdb.sitesearch.data.model.report;

import static org.gusdb.fgputil.iterator.IteratorUtil.toStream;

import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import org.apache.log4j.Logger;


import org.gusdb.fgputil.functional.FunctionalInterfaces.Procedure;
import org.gusdb.fgputil.json.JsonWriter;
import org.gusdb.wdk.core.api.JsonKeys;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.answer.stream.RecordStream;
import org.gusdb.wdk.model.answer.stream.RecordStreamFactory;
import org.gusdb.wdk.model.question.Question;
import org.gusdb.wdk.model.record.Field;
import org.gusdb.wdk.model.record.RecordClass;
import org.gusdb.wdk.model.record.RecordInstance;
import org.gusdb.wdk.model.record.TableField;
import org.gusdb.wdk.model.record.TableValue;
import org.gusdb.wdk.model.record.attribute.AttributeField;
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

  private static final Logger LOG = Logger.getLogger(SolrLoaderReporter.class);


  private String _batchType; // eg "organism"
  private int _batchTimestamp;
  private String _batchId;
  private String _batchName; // eg, "plasmodium falciparum 3d7"

  private static final String ATTR_PREFIX = "TEXT__";
  private static final String TABLE_PREFIX = "MULTITEXT__";
  private static final String PROJECT_ID_PROP = "PROJECT_ID";

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
  protected void writeResponseBody(OutputStream out, Procedure checkResponseSize) throws WdkModelException {
    
    Map<String, TableField> tablesForThisProject = filterFieldsByProject(_tables);
    Map<String, AttributeField> attrsForThisProject = filterFieldsByProject(_attributes);
    
    // create output writer and initialize record stream
    try (JsonWriter writer = new JsonWriter(out);
         RecordStream records = RecordStreamFactory.getRecordStream (
            _baseAnswer, attrsForThisProject.values(), tablesForThisProject.values())) {
      Question question = _baseAnswer.getIdsQueryInstance().getQuery().getContextQuestion();
      writer.array();
      for (RecordInstance record : records) {
        writer.value(formatRecord(record, question, attrsForThisProject.keySet(), tablesForThisProject.keySet(), _batchType, _batchId, _batchName, _batchTimestamp));
        checkResponseSize.perform();
      }
      writer.endArray();
    }
    catch (IOException e) {
      throw new WdkModelException("Unable to write reporter result to output stream", e);
    }
  }
  
  /**
   * find fields that either have no "includeProjects" <propertyList> or
   * that do, and match the projectId in model.prop.
   * (the wdk "project" for our model is SiteSearchData, thus we have to use
   * properties to track which component we are reporting on)
   */
  private <T extends Field> Map<String, T> filterFieldsByProject(Map<String, T> fields) {
    String projectId = // eg PlasmoDB (from model.prop file)
        _baseAnswer.getWdkModel().getProperties().get(PROJECT_ID_PROP);
    Predicate<Entry<String,T>> includeInProject = entry -> {
      String[] includeProjects = entry.getValue().getPropertyList("includeProjects");
      return includeProjects == null || includeProjects.length == 0 ? true :
          Arrays.asList(includeProjects).contains(projectId);
    };
    return fields.entrySet()
      .stream()
      .filter(includeInProject)
      .collect(Collectors.toMap(Entry::getKey, Entry::getValue));
  }
   
  private static JSONObject formatRecord(RecordInstance record, Question question,
                                         Set<String> attributeNames, Set<String> tableNames, String batchType, String batchId, String batchName, int batchTimestamp) throws WdkModelException {
    try {
      RecordClass recordClass = question.getRecordClass();
      Collection<String> pkValues = record.getPrimaryKey().getValues().values();
      String urlSegment = recordClass.getUrlSegment();
      Collection<String> idValues = new ArrayList<String>();
      idValues.add(urlSegment);
      idValues.addAll(pkValues);
      String idValuesString = idValues.stream().collect(Collectors.joining("__"));
      
      var obj = new JSONObject();
      obj.put("document-type", urlSegment);
      obj.put("primaryKey", pkValues); // multi string field. for forming record URLs
      obj.put("wdkPrimaryKeyString", String.join(",", pkValues)); // joined string field for sorting
      obj.put("batch-type", batchType);
      obj.put("batch-id", batchId);
      obj.put("batch-name", batchName);
      obj.put("batch-timestamp", batchTimestamp);

      for (String attributeName: attributeNames) {
        if (attributeName.equals("wdk_weight")) continue;
        if (!question.getAttributeFieldMap().containsKey(attributeName))
          throw new WdkModelException ("Invalid attribute name '" + attributeName + "'");
        String name = question.getAttributeFieldMap().get(attributeName).isInternal()?
              attributeName : ATTR_PREFIX + urlSegment + "_" + attributeName;
        String value = record.getAttributeValue(attributeName).getValue();
        obj.put(name, value);
        if (name.equals("project")) idValuesString += "_" + value; // append project id, if we have one
      }
      for (String tableName: tableNames) {
        TableField tableField = recordClass.getTableFieldMap().get(tableName);
        String name = tableField.isInternal()?
            tableName : TABLE_PREFIX + urlSegment + "_" + tableName;
        obj.put(name, aggregateTableValueJson(record.getTableValue(tableName)));
      }
      obj.put(JsonKeys.ID, idValuesString); // unique across all docs
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
