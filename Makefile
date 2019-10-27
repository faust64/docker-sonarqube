ADMIN_PASSWORD=admin
ROOT_DOMAIN=demo.local
SKIP_SQUASH?=1

.PHONY: build
build:
	SKIP_SQUASH=$(SKIP_SQUASH) hack/build.sh
.PHONY: test
test:
	SKIP_SQUASH=$(SKIP_SQUASH) TAG_ON_SUCCESS=$(TAG_ON_SUCCESS) TEST_MODE=true hack/build.sh

.PHONY: demo
demo:
	docker run -p9000:9000 \
	     -e SONAR_PROJECT=cicd \
	     -e SCANNER_PASSWORD=secret \
	     -e SCANNER_USER=scanner \
	     -e SONAR_PRIVATE=yes \
	     ci/sonarqube

.PHONY: run
run:
	docker run -p9000:9000 ci/sonarqube

.PHONY: ocbuild
ocbuild: occheck
	oc process -f openshift/imagestream.yaml | oc apply -f-
	BRANCH=`git rev-parse --abbrev-ref HEAD`; \
	if test "$$GIT_DEPLOYMENT_TOKEN"; then \
	    oc process -f openshift/build-with-secret.yaml \
		-p "GIT_DEPLOYMENT_TOKEN=$$GIT_DEPLOYMENT_TOKEN" \
		-p "SONARQUBE_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	else \
	    oc process -f openshift/build.yaml \
		-p "SONARQUBE_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	fi

.PHONY: ocdemo
ocdemo:
	oc process -f openshift/secret.yaml \
	    -p ADMIN_PASSWORD=$(ADMIN_PASSWORD) | oc apply -f-
	oc process -f openshift/run-ephemeral.yaml \
	    -p ROOT_DOMAIN=$(ROOT_DOMAIN) | oc apply -f-

.PHONY: ocpersistent
ocpersistent:
	oc process -f openshift/secret.yaml \
	    -p ADMIN_PASSWORD=$(ADMIN_PASSWORD) | oc apply -f-
	oc process -f openshift/run-persistent.yaml \
	    -p ROOT_DOMAIN=$(ROOT_DOMAIN) | oc apply -f-

.PHONY: occheck
occheck:
	oc whoami >/dev/null 2>&1 || exit 42

.PHONY: occlean
occlean: occheck
	oc process -f openshift/run-persistent.yaml \
	    | oc delete -f- || true
	oc process -f openshift/secret.yaml \
	    | oc delete -f- || true

.PHONY: ocpurge
ocpurge:
	oc process -f openshift/build-with-secret.yaml \
	    -p GIT_DEPLOYMENT_TOKEN=abc | oc delete -f- || true
	oc process -f openshift/imagestream \
	    | oc delete -f- || true
