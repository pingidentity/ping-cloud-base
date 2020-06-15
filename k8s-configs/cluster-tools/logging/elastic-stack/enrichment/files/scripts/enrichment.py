#!/usr/bin/python

# Pull Down Tor Nodes / AlienVault Feeds and convert to YAML for Logstash Enrichment
# This simple py Script downloads enrichment files and converts them to a Logstash format for enriching logs.

import urllib2, re
import requests
import sys, os, time
# from datetime import date

def logger(logType, msg):
    currentDateTime = str(time.strftime("%Y-%m-%d %T", time.localtime()))
    containerName = os.environ['CONTAINER_NAME']
    logEntry = logType + "\t" + currentDateTime + "\t" + containerName + "\t" + msg
    print(logEntry)
    logFileFullPath = os.environ['LOG_FILEPATH'] + "/" + containerName + "_" + str(time.strftime("%d.%m.%Y", time.localtime())) + ".log"
    try:
        logFile = open(logFileFullPath, 'a')
        logFile.write(logEntry)
        logFile.close()
    except Exception as e:
        print("ERROR\t" + currentDateTime + "\t" + "Error while trying to write log entry into file.")

def writeYAML_TOR(url, enrichmentFilePath):
    torNodes = requests.get(url)
    rawContent = torNodes.text
    if rawContent:
        logger("INFO", "Data was successfully pulled from %s." % url)
    else:
        logger("ERROR", "Data pulling from %s was failed." % url)
        sys.exit(1)
    lineContent = rawContent.splitlines()

    if lineContent:
        try:
            yamlFile = open(enrichmentFilePath, 'w+')
        except Exception as e:
            logger("ERROR", "Something went wrong while opening file %s! Traceback: %s" % (enrichmentFilePath, str(e.message)))
            sys.exit(1)
        for line in lineContent:
            if line.startswith("ExitAddress"):
                splitLine = line.split(" ")
                yamlFile.write("\"" + splitLine[1] + "\": \"YES\"" + "\n")
        logger("INFO", "File updated successfully: %s" % enrichmentFilePath)
        yamlFile.close()

def writeYAML_AV(url, enrichmentFilePath):
    try:
        yamlFile = open(enrichmentFilePath, 'w+')
    except Exception as e:
        logger("ERROR", "Something went wrong while opening file %s! Traceback: %s" % (enrichmentFilePath, str(e.message)))
        sys.exit(1)
    html = urllib2.urlopen(url)
    if html:
        logger("INFO", "Data was successfully pulled from %s." % url)
    else:
        logger("ERROR", "Data pulling from %s was failed." % url)
        sys.exit(1)
    file = os.path.basename(enrichmentFilePath)
    try:
        for line in html.readlines():
            line = re.sub('\\r|\\n','',line)
            newLine=line.split(' ', 1)[0]
            yamlFile.write("\"" + newLine + "\": \"YES\"" + "\n")
    except Exception as e:
        logger("ERROR", "%s: Something went wrong while file modification. Traceback: %s" % (file, str(e.message)))
    else:
        logger("INFO", "File updated successfully: %s" % file)
    yamlFile.close()

def getLastModifiedTime(url):
    file = os.path.basename(url)
    try:
        mod_time = time.ctime(os.path.getmtime(url))
    except Exception as e:
        logger("ERROR", "%s: Something went wrong while getting file last modification time." % file)
    else:
        logger("INFO", "%s: last modified: %s" % (file, mod_time))

def checkFileSize(url):
    file = os.path.basename(url)
    size = os.path.getsize(url)
    if size:
        logger("INFO", "%s: size: %s" % (file, str(size)))
    else:
        logger("ERROR", "%s: empty file! It might crash Logstash! Aborting." % file)
        sys.exit(1)

#Start Script #GRAB 2 FEEDS AND CONVERT TO YAML FOR LOGSTASH

# Get source URLs from env vars 
try:
    torFeedURL = os.environ['ENRICHMENT_TOR_FEED_URL']
    alienvaultFeedURL = os.environ['ENRICHMENT_ALIEN_VAULT_FEED_URL']
    enrichmentFilePath = os.environ['ENRICHMENT_FILEPATH']
except Exception as e:
    logger("ERROR", "Error while getting environment variables: %s" % e.message)
    sys.exit(1)

logger("INFO", "Environment variables successfully obtained.")    

enrichmentFilePath_TOR = enrichmentFilePath + "TorNodes.yml"
enrichmentFilePath_AV = enrichmentFilePath + "AlienVaultIP.yml"
enrichmentFilePath_KC = enrichmentFilePath + "KnownCountries.yml"
enrichmentFilePath_MC = enrichmentFilePath + "MaliciousCountries.yml"

enrichmentFiles = [ enrichmentFilePath_TOR, enrichmentFilePath_AV, enrichmentFilePath_KC, enrichmentFilePath_MC ]

writeYAML_TOR(torFeedURL, enrichmentFilePath_TOR)
writeYAML_AV(alienvaultFeedURL, enrichmentFilePath_AV)

logger("INFO", "Enrichment pull completed.")

for fileUrl in enrichmentFiles:
    getLastModifiedTime(fileUrl)
    checkFileSize(fileUrl)

logger("INFO", "Enrichment job done!")