#!/bin/bash

##########################################################################################
# This is a map of the Beluga versioned images within this repo
# This script is used by the tag-release.sh script to know what images to
#   auto replace version strings for when tagging a release or creating a new branch
#   as we break up the mono-repo, these images will move to a file within its own repo
#   instead of here in the PCB repo
##########################################################################################

export IMAGE_MAP="pingaccess
   pingaccess-was
   pingfederate
   pingdirectory
   pingdelegator
   pingcentral
   pingdatasync
   argocd-bootstrap
   bootstrap
   p14c-integration
   metadata
   healthcheck
   ansible-beluga
   logstash
   grafana
   enrichment-bootstrap
   prometheus-json-exporter
   prometheus-job-exporter
   newrelic-tags-exporter
   nri-kubernetes
   robot-framework
   sigsci-nginx-ingress-controller
   sigsci-agent"