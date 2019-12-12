#!/bin/sh

set -e

echo "**** Preparing SonarQube PVC"
if ! test -d /opt/sonarqube/data/extensions; then
    mkdir -p /opt/sonarqube/data/extensions
    ls /opt/sonarqube/extensions-RO 2>/dev/null |
	while read extension
	do
	    echo " ++++ Installing Extension ${extension}"
	    cp -pr "/opt/sonarqube/extensions-RO/$extension" /opt/sonarqube/data/extensions/
	done
else
    echo " ++++ Resetting ElasticSearch"
    if ! find /opt/sonarqube/data/es6 -name '*lock' -type f -exec rm -f {} \;; then
	echo " +++++ Warning: ES lock files may still be there" >&2
    fi
fi

if ! test -d /opt/sonarqube/data/extensions/plugins; then
    rm -f /opt/sonarqube/data/extensions/plugins
    mkdir -p /opt/sonarqube/data/extensions/plugins
fi
if test -d /opt/sonarqube/lib/bundled-plugins; then
    for plugin in /opt/sonarqube/lib/bundled-plugins/*
    do
	plugin_base_name=$(basename ${plugin%-*})
	if test "$(ls /opt/sonarqube/data/extensions/plugins/$plugin_base_name* 2>/dev/null | awk 'END{print NR}')" = 0; then
	    echo "  ++++ Installing plugin $plugin..."
	    cp -p "$plugin" /opt/sonarqube/data/extensions/plugins/
	fi
    done
fi
if test "$ENABLE_OAUTH"; then
    INSTALL_PLUGINS="$INSTALL_PLUGINS https://github.com/rht-labs/sonar-auth-openshift/releases/latest/download/sonar-auth-openshift-plugin.jar"
fi
if test "$INSTALL_PLUGINS"; then
    (
	cd /opt/sonarqube/data/extensions/plugins
	for url in $INSTALL_PLUGINS
	do
	    basename=$(basename "$url")
	    test -f "$basename" && continue
	    echo " ++++ Fetching Extension $basename"
	    wget "$url"
	done
    )
fi
if test "$REMOVE_PLUGINS"; then
    (
	cd /opt/sonarqube/data/extensions/plugins
	for plugin in $REMOVE_PLUGINS
	do
	    echo " ++++ Purging Extension $plugin"
	    rm -rvf $plugin*
	done
    )
fi
echo "**** Done Preparing PVC"

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
grep -v ^sonar /etc/passwd >/opt/sonarqube/data/passwd
echo "sonar:x:${USER_ID}:${GROUP_ID}::/opt/sonarqube/data:/bin/bash" >>/opt/sonarqube/data/passwd
export NSS_WRAPPER_PASSWD=/opt/sonarqube/data/passwd
export NSS_WRAPPER_GROUP=/etc/group
export LD_PRELOAD=/usr/lib/libnss_wrapper.so

if test -x $SONARQUBE_HOME/bin/provision.sh; then
    if ! test -s $SONARQUBE_HOME/data/current_local_password; then
	echo admin >$SONARQUBE_HOME/data/current_local_password
    fi
    echo Executing provision.sh
    nohup $SONARQUBE_HOME/bin/provision.sh &
fi

if test "$ENABLE_OAUTH"; then
    OC_ROOT_DOMAIN=${OC_ROOT_DOMAIN:-demo.local}
    exec java -jar lib/sonar-application-$SONAR_VERSION.jar \
	-Dsonar.log.console=true \
	-Dsonar.jdbc.username="$SONARQUBE_JDBC_USERNAME" \
	-Dsonar.jdbc.password="$SONARQUBE_JDBC_PASSWORD" \
	-Dsonar.jdbc.url="$SONARQUBE_JDBC_URL" \
	-Dsonar.auth.openshift.isEnabled=true \
	-Dsonar.auth.openshift.webUrl=https://oauth-openshift.apps.$OC_ROOT_DOMAIN \
	-Dsonar.web.javaAdditionalOpts="$SONARQUBE_WEB_JVM_OPTS -Djava.security.egd=file:/dev/./urandom" \
	"$@"
else
    exec java -jar lib/sonar-application-$SONAR_VERSION.jar \
	-Dsonar.log.console=true \
	-Dsonar.jdbc.username="$SONARQUBE_JDBC_USERNAME" \
	-Dsonar.jdbc.password="$SONARQUBE_JDBC_PASSWORD" \
	-Dsonar.jdbc.url="$SONARQUBE_JDBC_URL" \
	-Dsonar.web.javaAdditionalOpts="$SONARQUBE_WEB_JVM_OPTS -Djava.security.egd=file:/dev/./urandom" \
	"$@"
fi
