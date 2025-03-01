package org.eupathdb.sitesearch.wsfplugin;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.ArrayUtil;
import org.gusdb.fgputil.FormatUtil;
import org.gusdb.fgputil.db.runner.SQLRunner;
import org.gusdb.fgputil.db.runner.SQLRunnerException;
import org.gusdb.fgputil.runtime.GusHome;
import org.gusdb.fgputil.runtime.InstanceManager;
import org.gusdb.oauth2.client.veupathdb.UserInfo;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.question.Question;
import org.gusdb.wdk.model.record.PrimaryKeyDefinition;
import org.gusdb.wdk.model.record.RecordClass;
import org.gusdb.wdk.model.user.UserFactory;
import org.gusdb.wsf.plugin.AbstractPlugin;
import org.gusdb.wsf.plugin.PluginModelException;
import org.gusdb.wsf.plugin.PluginRequest;
import org.gusdb.wsf.plugin.PluginResponse;
import org.gusdb.wsf.plugin.PluginUserException;

public class CommunityStudyIdsPlugin extends AbstractPlugin {

    private static final Logger LOG = Logger.getLogger(CommunityStudyIdsPlugin.class);

    static final String PROJECT_ID_PROPLIST = "projectId";  // this is a <propertyList> used in the model xml
    static final String VDI_CONTROL_SCHEMA_PROP_KEY = "VDI_CONTROL_SCHEMA";  // this is in model.prop
    static final String OAUTH_SERVICE_URL_PROP_KEY = "OAUTH_SERVICE_URL";  // this is in model.prop

    @Override
    public String[] getRequiredParameterNames() {
        return new String[0];
    }

    @Override
    public String[] getColumns(PluginRequest request) throws PluginModelException {
        RecordClass recordClass = getQuestion(request).getRecordClass();
        PrimaryKeyDefinition pkDef = recordClass.getPrimaryKeyDefinition();
        String[] dynamicColumns =  new String[]{ "owner_name", "owner_institution" };
        String[] columns = ArrayUtil.concatenate(pkDef.getColumnRefs(), dynamicColumns);
        LOG.info("CommunityStudyIdsPlugin instance will return the following columns: " + FormatUtil.join(columns, ", "));
        return columns;
    }

    /*
     - query appDB VDI control tables to get map from owner's user_id to dataset id. store in memory.
     - query (REST) oauth service to get user_id:details mapping, for the owners of community datasets.  store in memory
     - merge these two, to produce (dataset_id, owner_name, owner_institution)
    */
    @Override
    protected int execute(PluginRequest request, PluginResponse response) throws PluginModelException, PluginUserException {
        Question question = getQuestion(request);
        WdkModel wdkModel = question.getRecordClass().getWdkModel();
        List<UserDatasetIds> communityDatasetIds = getCommunityDatasetIds(request, question, wdkModel);
        UserFactory userFactory = new UserFactory(wdkModel);
        List<Long> userIds = communityDatasetIds.stream().map(udi -> udi.ownerId).collect(Collectors.toList());
        Map<Long, UserInfo> userMap = userFactory.getUsersById(userIds);
        for (UserDatasetIds udi : communityDatasetIds) {
            String[] row = {udi.datasetId, userMap.get(udi.ownerId).getDisplayName(), userMap.get(udi.ownerId).getOrganization()};
            response.addRow(row);
        }
        return 0;
    }

    /* we store in memory a map of ownerUserId to VDI dataset id, for each community dataset.
       We assume there are not too many to fit comfortably into memory.  (100k at absolute most)
    */
     List<UserDatasetIds> getCommunityDatasetIds(PluginRequest request, Question question, WdkModel wdkModel) throws PluginModelException {

        if (! wdkModel.getProperties().containsKey(VDI_CONTROL_SCHEMA_PROP_KEY))
            throw new PluginModelException("Can't find property'" + VDI_CONTROL_SCHEMA_PROP_KEY + "' in model.prop file");

        String vdiControlSchema = wdkModel.getProperties().get(VDI_CONTROL_SCHEMA_PROP_KEY);

        String[] projectsPropList = question.getPropertyList(PROJECT_ID_PROPLIST);
        if (projectsPropList == null)
            throw new PluginModelException("Can't find <propertyList> '" + PROJECT_ID_PROPLIST + "' in ID question for community datasets");
        if (projectsPropList.length != 1)
            throw new PluginModelException("Error: require a single value in <propertyList> '" + PROJECT_ID_PROPLIST + "' in ID question for community datasets");
        String projectId = projectsPropList[0];

        DataSource appDs = wdkModel.getAppDb().getDataSource();
        String sql = "select distinct user_dataset_id, user_id " +
                "from " + vdiControlSchema + ".AvailableUserDatasets " +
                "where project_id = '" + projectId + "' " +
                "and is_public = 1 and is_owner = 1";
        try {
            return new SQLRunner(appDs, sql).executeQuery(rs -> {
               List<UserDatasetIds> ownerDatasetIds = new ArrayList<>();
                while (rs.next()) {
                    String datasetId = rs.getString(1);
                    Long ownerUserId = rs.getLong(2);
                    ownerDatasetIds.add(new UserDatasetIds(ownerUserId, datasetId));
                }
                return ownerDatasetIds;
            });
        }
        catch (SQLRunnerException e) {
            throw new PluginModelException("Unable to generate project ID map for organism doc type", e.getCause());
        }
    }

    @Override
    public void initialize(PluginRequest request) throws PluginModelException { }

    @Override
    public void validateParameters(PluginRequest request) throws PluginModelException, PluginUserException { }

    static Question getQuestion(PluginRequest request) throws PluginModelException {
        String questionFullName = request.getContext().get(Utilities.CONTEXT_KEY_QUESTION_FULL_NAME);
        WdkModel wdkModel = InstanceManager.getInstance(WdkModel.class, GusHome.getGusHome(), request.getProjectId());
        return wdkModel.getQuestionByFullName(questionFullName).orElseThrow(() -> new PluginModelException("Could not find context question: " + questionFullName));
    }

    class UserDatasetIds {
        UserDatasetIds(Long ownerId, String datasetId) {
            this.ownerId = ownerId;
            this.datasetId = datasetId;
        }
        Long ownerId;
        String datasetId;
    }
}
