FROM openjdk:11

# SonarQube server image for OpenShift Origin

ENV SONAR_VERSION=7.9.1 \
    SONARQUBE_HOME=/opt/sonarqube \
    DEBIAN_FRONTEND=noninteractive \
    DESCRIPTION="SonarQube is an open source platform developed by SonarSource for continuous \
inspection of code quality to perform automatic reviews with static analysis of code to detect \
bugs, code smells, and security vulnerabilities on 20+ programming languages. SonarQube offers \
reports on duplicated code, coding standards, unit tests, code coverage, code complexity, \
comments, bugs, and security vulnerabilities."

LABEL description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="SonarQube ${SONAR_VERSION}" \
      io.openshift.expose-services="9000:http" \
      io.openshift.tags="ci,sonarqube,sonar,sonarqube${SONAR_VERSION}" \
      io.openshift.non-scalable="true" \
      help="For more information visit https://github.com/faust64/docker-sonarqube" \
      maintainer="Samuel MARTIN MORO <faust64@gmail.com>" \
      release="1" \
      version="${SONAR_VERSION}"

USER root
RUN echo "# Install Dumb-init" \
    && apt-get update \
    && apt-get -y install dumb-init \
    && if test "$DO_UPGRADE"; then \
	echo "# Upgrade Base Image"; \
	apt-get -y upgrade; \
	apt-get -y dist-upgrade; \
    fi \
    && apt-get install -y unzip curl libnss-wrapper \
    && cd /opt \
    && curl -o sonarqube.zip -fSL https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip \
    && unzip sonarqube.zip \
    && mv sonarqube-$SONAR_VERSION sonarqube \
    && rm -f sonarqube.zip

ADD config /
RUN useradd -r sonar \
    && chmod 775 $SONARQUBE_HOME/bin/run_sonarqube.sh \
    && /usr/bin/fix-permissions $SONARQUBE_HOME \
    && mv $SONARQUBE_HOME/extensions $SONARQUBE_HOME/extensions-RO \
    && ln -sf $SONARQUBE_HOME/data/extensions $SONARQUBE_HOME/

USER sonar
WORKDIR $SONARQUBE_HOME
ENTRYPOINT ["dumb-init","--","./bin/run_sonarqube.sh"]
