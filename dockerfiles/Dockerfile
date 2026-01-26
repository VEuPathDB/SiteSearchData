############################################################
#
#  Build Environment
#
############################################################

FROM veupathdb/alpine-dev-base:jdk-21-gradle-8.7 AS build

ARG GITHUB_USERNAME
ARG GITHUB_TOKEN


ENV ANT_VERSION=1.10.8 \
    ANT_HOME=/opt/ant \
    PATH=${PATH}:/opt/ant/bin


#
#  Install Apache Ant
#
RUN wget http://archive.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
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
    bash \
    perl \
    bash \
    maven


ENV BASE_GUS=/tmp/base_gus
ENV GUS_HOME="${BASE_GUS}/gus_home" \
    PROJECT_HOME="${BASE_GUS}/project_home" \
    GIT_HOME=https://github.com/VEuPathDB
ENV PATH="${GUS_HOME}/bin:${PROJECT_HOME}/install/bin:${PATH}"


WORKDIR ${PROJECT_HOME}


#
# Copy in SiteSearchData source
#
COPY . SiteSearchData/


#
# Build Project Home
#
RUN git clone https://github.com/EuPathDB/install.git \
 && git clone https://github.com/EuPathDB/FgpUtil.git \
 && git clone https://github.com/EuPathDB/EbrcWebsiteCommon.git \
 && git clone https://github.com/EuPathDB/WDK.git \
 && git clone https://github.com/EuPathDB/WSF.git


 #
# Project Build
#
RUN mkdir -p ${GUS_HOME}/config \
 && cp ${PROJECT_HOME}/install/config/gus.config.sample ${GUS_HOME}/config/gus.config \
 && env \
 && /bin/bash bld SiteSearchData


############################################################
#
#  Runtime Environment
#
############################################################

FROM foxcapades/alpine-oracle:1.6

ENV BASE_GUS=/tmp/base_gus 
ENV GUS_HOME=${BASE_GUS}/gus_home
ENV PATH="${GUS_HOME}/bin:${JAVA_HOME}/bin:${PATH}"

# python3/requests for loading scripts
RUN apk add -u --no-cache \
    python3 \
    py3-pip \
    gettext \
    build-base \
    python2-dev \
    libffi-dev \
    libressl-dev \
    perl \
    wget \
    openjdk11 \
 && pip3 install requests \
 && mkdir -p ${GUS_HOME}/lib/java/db_driver \
 && cp /jdbc/* ${GUS_HOME}/lib/java/db_driver

COPY --from=build ${GUS_HOME} ${GUS_HOME}
COPY [ \
  "dockerfiles/entrypoint.sh", \
  "config/site-search-config.tpl.json", \
  "/tmp/" \
]

RUN chmod +x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]
EXPOSE 9988

CMD wdkServer SiteSearchData http://0.0.0.0:9988
