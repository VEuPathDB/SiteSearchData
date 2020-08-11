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

COPY project_home/ ${PROJECT_HOME}
COPY dockerfiles/entrypoint.sh .

# Run after the copy to prevent issues with cached image layers.
RUN mkdir -p ${GUS_HOME}/config \
 && cp ${PROJECT_HOME}/install/gus.config.sample ${GUS_HOME}/config/gus.config \
 && env \
 && bld SiteSearchData

############################################################
#
#  Runtime Environment
#
############################################################

FROM foxcapades/alpine-oracle:1.3

ENV BASE_GUS=/tmp/base_gus \
    JAVA_HOME=/opt/jdk
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
 && pip3 install requests \
 && mkdir -p ${GUS_HOME}/lib/java/db_driver \
 && cp /jdbc/* ${GUS_HOME}/lib/java/db_driver \
 && wget https://download.java.net/java/early_access/alpine/10/binaries/openjdk-15-ea+10_linux-x64-musl_bin.tar.gz \
 && tar -xzf openjdk-15-ea+10_linux-x64-musl_bin.tar.gz \
 && rm openjdk-15-ea+10_linux-x64-musl_bin.tar.gz \
 && mv jdk-15 ${JAVA_HOME}

COPY --from=build ${GUS_HOME} ${GUS_HOME}
COPY [ \
  "dockerfiles/entrypoint.sh", \
  "config/site-search-config.tpl.json", \
  "/tmp/" \
]


COPY bin/* /usr/local/bin

RUN chmod +x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]
EXPOSE 9988

CMD wdkServer SiteSearchData http://0.0.0.0:9988
