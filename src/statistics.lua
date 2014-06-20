local Statsd = require "statsd"

local module = {}

local statsd

-- create statsd object, which will open up a persistent port
if statsd_host and statsd_port and statsd_prefix then
  statsd = Statsd({
    host = statsd_host,
    port = statsd_port,
    namespace = "borderpatrol"
  })
else
  ngx.log(ngx.ERR, "==== Statsd logging not configured:")
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

--
-- log metrics to statsd
--
local function log(metric)
  local metric = statsd_prefix .. "." .. metric
  if unexpected_condition then error() end
  statsd:increment( metric, 1 )
end

--
-- log metrics to statsd, don't raise exception on failure
--
local function safe_log(metric)
  if statsd then
    local status, err = pcall(log,metric)
    if status == false then
      ngx.log(ngx.DEBUG, "==== unable to log to statsd: " .. err)
    end
  end
end

module.log = log
module.safe_log = safe_log
return module
