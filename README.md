# SonarQube

OpenShift-friendly SonarQube image, based on
https://github.com/SonarSource/docker-sonarqube

Build with:
```
$ make build
```

If you want to try it quickly on your local machine after make, run:
```
$ make run
```

You should be able to access it on `localhost:9000`, login as `admin`, password
`admin`

Build on OpenShift:
```
$ make ocbuild
```

Deploy ephemeral demo on OpenShift:
```
$ make ROOT_DOMAIN=apps.examplecom ADMIN_PASSWORD=secret ocdemo
```

Deploy persistent sonarqube to OpenShift (requires default StorageClass):
```
$ make ROOT_DOMAIN=apps.examplecom ADMIN_PASSWORD=secret ocpersistent
```

Clean up deployment:
```
$ make occlean
```

Purge build assets:
```
$ make ocpurge
```

Environment variables and volumes
----------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker `run` command.

|    Variable name            |    Description                          | Default      |
| :-------------------------- | --------------------------------------- | ------------ |
|  `ADMIN_PASSWORD`           | Administrator Password                  | `admin`      |
|  `SCANNER_PASSWORD`         | Default Scanner Password                | undef        |
|  `SCANNER_USER`             | Default Scanner User                    | undef        |
|  `SONAR_PRIVATE`            | Close Anonymous Accesses to Sonarqube   | undef        |
|  `SONAR_PROJECT`            | Default Project                         | undef        |
|  `SONARQUBE_JDBC_PASSWORD`  | Postgres DB Password                    | undef        |
|  `SONARQUBE_JDBC_URL`       | Postgres DB URL                         | undef        |
|  `SONARQUBE_JDBC_USERNAME`  | Postgres DB Username                    | undef        |

You can also set the following mount points by passing the
`-v /host:/container` flag to Docker.

|  Volume mount point        | Description                  |
| :------------------------- | ---------------------------- |
|  `/opt/sonarqube/conf`     | SonarQube configuration      |
|  `/opt/sonarqube/data`     | SonarQube runtime data       |
|  `/opt/sonarqube/data/es6` | SonarQube es6 (can be reset) |
|  `/opt/sonarqube/logs`     | SonarQube logs               |
|  `/opt/sonarqube/temp`     | SonarQube temp               |
