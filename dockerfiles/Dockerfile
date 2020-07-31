############################################################
#
#  Build Environment
#
############################################################

FROM veupathdb/alpine-dev-base:latest AS build

#
#  Install Apache Ant
#

ENV ANT_VERSION=1.10.8 \
    ANT_HOME=/opt/ant \
    PATH=${PATH}:/opt/ant/bin

RUN wget http://www.us.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
 && tar -xzf apache-ant-${ANT_VERSION}-bin.tar.gz \
 && mv apache-ant-${ANT_VERSION} ${ANT_HOME} \
 && rm apache-ant-${ANT_VERSION}-bin.tar.gz

#
# Install Package Dependencies
#

RUN apk add -u --no-cache \
    npm \
    nodejs \
    git \
    perl

#
# Project Build
#

ENV BASE_GUS=/tmp/base_gus
ENV GUS_HOME="${BASE_GUS}/gus_home" \
    PROJECT_HOME="${BASE_GUS}/project_home" \
    GIT_HOME=https://github.com/VEuPathDB
ENV PATH="${GUS_HOME}/bin:${PROJECT_HOME}/install/bin:${PATH}"

WORKDIR /tmp

COPY . ${PROJECT_HOME}/SiteSearchData/
COPY dockerfiles/entrypoint.sh .

# Run after the copy to prevent issues with cached image layers.
RUN git clone ${GIT_HOME}/install ${PROJECT_HOME}/install \
 && git clone ${GIT_HOME}/FgpUtil ${PROJECT_HOME}/FgpUtil \
 && git clone ${GIT_HOME}/WDK     ${PROJECT_HOME}/WDK \
 && git clone ${GIT_HOME}/WSF     ${PROJECT_HOME}/WSF \
 && mkdir -p ${GUS_HOME}/config \
 && cp ${PROJECT_HOME}/install/gus.config.sample ${GUS_HOME}/config/gus.config \
 && env \
 && bld SiteSearchData

############################################################
#
#  Runtime Environment
#
############################################################

FROM foxcapades/alpine-oracle:1.3

ENV BASE_GUS=/tmp/base_gus
ENV GUS_HOME=${BASE_GUS}/gus_home
ENV PATH="${GUS_HOME}/bin:${PATH}" \
    TNS_ADMIN=/tmp/oracle

# python3/requests for loading scripts
RUN apk add -u --no-cache python3 py3-pip gettext \
 && ln -s /usr/bin/python3 /usr/bin/python \
 && pip install requests \
 && mkdir -p ${TNS_ADMIN}

COPY --from=build ${GUS_HOME} ${GUS_HOME}
COPY [ \
  "dockerfiles/entrypoint.sh", \
  "config/conifer_site_vars.tpl.yml", \
  "config/site-search-config.tpl.json", \
  "config/ldap.tpl.ora", \
  "/tmp/" \
]

RUN chmod +x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]
EXPOSE 9988

CMD wdkServer SiteSearchData http://0.0.0.0:9988
