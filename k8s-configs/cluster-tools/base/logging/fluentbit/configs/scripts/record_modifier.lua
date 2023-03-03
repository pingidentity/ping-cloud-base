# This script is called by fluent-bit to append a stream_name to the log message.
function record_modifier(tag, timestamp, record)
  if record["kubernetes"] ~= nil then
    new_record = record
    new_record["stream_name"] = record["kubernetes"]["pod_name"].."_"..record["kubernetes"]["namespace_name"].."_"..record["kubernetes"]["container_name"]
    return 1, timestamp, new_record
  else
    output = tag .. ":  [" .. string.format("%f", timestamp) .. ", { "
    for key, val in pairs(record) do
      output = output .. string.format(" %s => %s,", key, val)
    end
    output = string.sub(output,1,-2) .. " }]"
    print(output)
    return -1, 0, 0
  end
end