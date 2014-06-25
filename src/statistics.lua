local Statsd = require "statsd"

local module = {}

local statsd

-- create statsd object, which will open up a persistent port
if statsd_host and statsd_port then
  local namespace = statsd_namespace
  if namespace then
    statsd = Statsd({
      host = statsd_host,
      port = statsd_port,
      namespace = namespace
    })
  else
    statsd = Statsd({
      host = statsd_host,
      port = statsd_port
    })
  end
else
  ngx.log(ngx.INFO, "==== Statsd logging not configured:")
end

--
-- log metrics to statsd
--
local function log(metric)
  if statsd then
    local met
    if statsd_prefix then
       met = statsd_prefix .. "." .. metric
    else
      met = metric
    end
    local status, err = pcall(function() statsd:increment( met, 1) end)
    if status == false then
      ngx.log(ngx.DEBUG, "==== unable to log to statsd: " .. err)
    end
  end
end
module.log = log
return module
