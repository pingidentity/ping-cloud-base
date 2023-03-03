# This script is called by fluent-bit to append a time to the log message.
function append_tag(tag, timestamp, record)
  new_record = record
  host = record["private_ip"]:gsub("%.", "-")
  new_record["host"] = "ip-"..host
  return 1, timestamp, new_record
end
