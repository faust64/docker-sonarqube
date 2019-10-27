#!/bin/sh

if test "$DEBUG"; then
    set -x
fi

if test -s $SONARQUBE_HOME/data/current_local_password; then
    password=$(head -1 $SONARQUBE_HOME/data/current_local_password | tr -d '\n')
else
    echo "[ERR] File $SONARQUBE_HOME/data/current_local_password doesn't exist."
    echo "This file should include your current local password."
    exit 1
fi >&2
test -z "$ADMIN_PASSWORD" && ADMIN_PASSWORD="$password"

pretty_sleep()
{
    secs="${1:-60}"
    tool="${2:-service}"
    while test "$secs" -gt 0
    do
	/bin/echo -ne "$tool unavailable, sleeping for: $secs\033[0Ks\r"
	sleep 1
	secs=`expr $secs - 1`
    done
}

echo "* Waiting for the SonarQube to become available - this can take a few minutes"
cpt=0
sonar_host=http://localhost:9000
username=admin
while ! curl -I -s "$sonar_host/" | head -n 1 | awk '{print $2}' | grep 200 >/dev/null
do
    test "$cpt" -ge 60 && break
    pretty_sleep 10 SonarQube
    cpt=`expr $cpt + 1`
done
if ! curl -I -s "$sonar_host/" | head -n 1 | awk '{print $2}' | grep 200 >/dev/null; then
    echo bailing out
    exit 1
fi

echo "* Waiting for API to become available"
cpt=0
while ! curl -u "$username:$password" "$sonar_host/api/users/search" 2>/dev/null | grep "\"$username\"" >/dev/null
do
    test "$cpt" -ge 60 && break
    pretty_sleep 10 API
    cpt=`expr $cpt + 1`
done
if ! curl -u "$username:$password" "$sonar_host/api/users/search" 2>/dev/null | grep "\"$username\"" >/dev/null; then
    echo bailing out
    exit 1
fi

sleep 10
cat <<EOF
 == Provisioning Integration API Scripts Starting ==

Publishing and executing on $sonar_host
EOF

if test "$SONAR_PROJECT"; then
    if ! curl -u "$username:$password" "$sonar_host/api/projects/index" 2>/dev/null | grep "\"$SONAR_PROJECT\"" >/dev/null; then
	if ! curl -u "$username:$password" -X POST "$sonar_host/api/projects/create?name=$SONAR_PROJECT&project=$SONAR_PROJECT"; then
	    echo " -- Failed creating project $SONAR_PROJECT"
	fi
    else
	echo " -- Re-using previously existing project $SONAR_PROJECT"
    fi
fi
if test "$SCANNER_USER" -a "$SCANNER_PASSWORD"; then
    if ! curl -u "$username:$password" "$sonar_host/api/users/search" 2>/dev/null | grep "\"$SCANNER_USER\"" >/dev/null; then
        if ! curl -u "$username:$password" -X POST "$sonar_host/api/users/create?login=$SCANNER_USER&name=$SCANNER_USER&password=$SCANNER_PASSWORD"; then
	    echo " -- Failed creating user $SCANNER_USER"
	else
	    for permission in scan provisioning
	    do
		if ! curl -u "$username:$password" -X POST "$sonar_host/api/permissions/add_user?permission=$permission&login=$SCANNER_USER"; then
		    echo " -- Failed setting $permission permission for $SCANNER_USER user"
		fi
	    done
	    if test "$SONAR_PROJECT"; then
		for privilege in scan user
		do
		    if ! curl -u "$username:$password" -X POST "$sonar_host/api/permissions/add_user?permission=$privilege&projectKey=$SONAR_PROJECT&login=$SCANNER_USER"; then
			echo " -- Failed setting $privilege privilege for $SCANNER_USER user on $SONAR_PROJECT project"
		    fi
		done
	    fi
	fi
    else
	echo " -- Re-using previously existing user $SCANNER_USER"
    fi
fi
if test "$SONAR_PRIVATE"; then
    for permission in scan provisioning
    do
	if ! curl -u "$username:$password" -X POST "$sonar_host/api/permissions/remove_group?permission=$permission&groupName=anyone"; then
	    echo " -- Failed disabling $permission permission for unauthenticated users"
	fi
    done
fi
if test "$ADMIN_PASSWORD" != "$password"; then
    DBHOST=$(echo "$SONARQUBE_JDBC_URL" | sed 's|jdbc:||')
    SALTED=$(htpasswd -bnBC 10 "" "$ADMIN_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')
    echo " -- Setting SonarQube default admin password..."
    PGPASSWORD="$SONARQUBE_JDBC_PASSWORD" psql "-U$SONARQUBE_JDBC_USERNAME" "$DBHOST" -c "update users set crypted_password='$SALTED', salt=null, hash_method='BCRYPT' where login = 'admin'"
    if test $? -eq 0; then
	echo "$ADMIN_PASSWORD" >$SONARQUBE_HOME/data/current_local_password
	echo " -- Successfully changed admin password"
    else
	echo " -- Failed setting admin password"
    fi
fi

echo " == Provisioning Scripts Completed =="
