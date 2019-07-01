#!/bin/bash
# Setup Jenkins Project
# ### if [ "$#" -ne 3 ]; then
# ###     echo "Usage:"
# ###     echo "  $0 GUID REPO CLUSTER"
# ###     echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
# ###     exit 1
# ### fi
# ### 
# ### GUID=$1
# ### REPO=$2
# ### CLUSTER=$3

# Added by RIX
UN=$1
PW=$2
export GUID="c740"
export REPO="https://github.com/rkuntze/advdev_homework.git"
export CLUSTER="https://master.na311.openshift.opentlc.com"


echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# LOGIN:
oc login -u ${UN} -p ${PW} ${CLUSTER}


# Set up Jenkins with sufficient resources
# TBD-RIX
oc new-project ${GUID}-jenkins --display-name "${GUID} Shared Jenkins"
# Main App Jenkins Master from openshift internal template jenkins-persistent
# causes errors: oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true
## -- in case of pvc errors:
oc new-app jenkins-ephemeral --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true


# Create custom agent container image with skopeo
# TBD-RIX
# Jenkins Slave Image:
oc new-build  -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins


# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
# TBD-RIX:
# Jenkins Pipeline:
echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "tasks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/rkuntze/advdev_homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: openshift-tasks/Jenkinsfile
kind: List
metadata: []" | oc create -f - -n ${GUID}-jenkins


# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done