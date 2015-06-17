local json = require("json")
--
-- This script serves up an HTML page that displays current health of the
-- BorderPatrol. The only check, currently, is that memcache is reachable.
--

-- take local_health and SET-OR it with upstream_health
local function merge_tables(upstream_health, local_health)
  for upstream, health in pairs(upstream_health) do
    local_health[upstream] = health
  end

  return local_health
end

-- return a table {borderpatrol = {... "version", "stats" and "error"} }
local function get_local_health()
  local tbl = {}
  tbl["stats"] = {}
  tbl["version"] = bp_version

  local res = ngx.location.capture('/session/health?cmd=stats')
  if not (res.status == ngx.HTTP_OK) then
    tbl["error"] = true
  end
  tbl["status"] = res.status
  tbl["stats"]["memcached"] = {status=res.status, body=res.body}

  return {borderpatrol=tbl}
end

-- returns a table, e.g. {account={status=200, body={}}}
local function get_upstreams_health()
  local tbl = {}

  for k, v in pairs(health_checks) do
    local res = ngx.location.capture(v)
    tbl[k] = {status=res.status, body=json.decode(res.body)}
  end

  return tbl
end

-- checks if there are any error conditions
local function has_error(healths)
  for k,v in pairs(healths) do
    if not (v["status"] == ngx.HTTP_OK) then
      return true
    end
  end
  return false
end

local healths = merge_tables(get_local_health(), get_upstreams_health())

if (has_error(healths)) then
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
else
  ngx.status = ngx.HTTP_OK
end

ngx.header.content_type = 'application/json'
ngx.print(json.encode(healths))
