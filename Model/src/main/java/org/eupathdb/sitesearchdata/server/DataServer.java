package org.eupathdb.sitesearchdata.server;

import org.glassfish.jersey.server.ResourceConfig;
import org.gusdb.fgputil.runtime.GusHome;
import org.gusdb.fgputil.server.RESTServer;
import org.gusdb.fgputil.web.ApplicationContext;
import org.gusdb.wdk.controller.WdkApplicationContext;
import org.gusdb.wdk.service.WdkServiceApplication;
import org.json.JSONObject;

public class DataServer extends RESTServer {

  private static final String PROJECT_ID = "SiteSearchData";

  public static void main(String[] args) {
    new DataServer(args).start();
  }

  public DataServer(String[] commandLineArgs) {
    super(commandLineArgs);
  }

  @Override
  protected ResourceConfig getResourceConfig() {
    return new ResourceConfig().registerClasses(
        new WdkServiceApplication().getClasses());
  }

  @Override
  protected ApplicationContext createApplicationContext(JSONObject config) {
    return new WdkApplicationContext(
        // basically the replacement for config contained in web.xml; set init parameters
        GusHome.getGusHome(), // get from ENV
        PROJECT_ID,
        "/service"
    );
  }

  @Override
  protected boolean requiresConfigFile() {
    return false;
  }

}
