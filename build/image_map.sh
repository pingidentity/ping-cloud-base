#!/bin/bash

##########################################################################################
# This is a map of the Beluga versioned images within this repo
# This script is used by the tag-release.sh script to know what images to
#   auto replace version strings for when tagging a release or creating a new branch
#   as we break up the mono-repo, these images will move to a file within its own repo
#   instead of here in the PCB repo
##########################################################################################

export IMAGE_MAP="pingcloud-apps/pingaccess
   pingcloud-apps/pingaccess-was
   pingcloud-apps/pingfederate
   pingcloud-apps/pingdirectory
   pingcloud-apps/pingdelegator
   pingcloud-apps/pingcentral
   pingcloud-apps/pingdatasync
   pingcloud-services/argocd-bootstrap
   pingcloud-services/bootstrap
   pingcloud-services/p14c-integration
   pingcloud-services/metadata
   pingcloud-services/healthcheck
   pingcloud-solutions/ansible-beluga
   pingcloud-monitoring/logstash
   pingcloud-monitoring/grafana
   pingcloud-monitoring/enrichment-bootstrap
   pingcloud-monitoring/os-bootstrap
   pingcloud-monitoring/opensearch
   pingcloud-monitoring/prometheus-json-exporter
   pingcloud-monitoring/prometheus-job-exporter
   pingcloud-monitoring/newrelic-tags-exporter
   pingcloud-monitoring/nri-kubernetes
   pingcloud-services/robot-framework
   pingcloud-services/sigsci-nginx-ingress-controller
   pingcloud-services/sigsci-agent
   pingcloud-services/grp-radiusproxy
   pingcloud-services/ingress-bootstrap"
