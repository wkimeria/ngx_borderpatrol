local Statsd = require "statsd"

local module = {}

local statsd

-- create statsd object, which will open up a persistent port
if statsd_host then
  opts = {host = statsd_host}
  if statsd_port then
    opts.port = statsd_port
  end
  if statsd_namespace then
    opts.namespace = statsd_namespace
  end
  statsd = Statsd(opts)
else
  ngx.log(ngx.INFO, "==== Statsd logging not configured")
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
    local status, err = pcall(statsd.increment, statsd, met, 1)
    if status == false then
      ngx.log(ngx.ERR, "==== unable to log to statsd: " .. err)
    end
  end
end
module.log = log
return module
