--
-- This script serves up an HTML page that displays current health of the
-- BorderPatrol. The only check, currently, is that memcache is reachable.
--
local health_check = {}

-- print out the actual HTML
function health_check.output(errors)
  local output = [[
  <html>
    <head>
      <title>Border Patrol Health</title>
    </head>
    <body>
  ]]

  output = output .. "<h3>Version " .. bp_version .. "</h3>"

  if #errors > 0 then
    output = output .. "<h3>Errors</h3><ul>"
    for i, v in ipairs(errors) do
      output = output .. "<li>" .. v .. "</li>"
    end
    output = output .. "</ul>"
  else
    output = output .. "Everything is ok."
  end

  output = output .. [[
    </body>
  </html>
  ]]

  return output
end

local function get_errors()
  local errors = {}
  local res = ngx.location.capture('/session?id=health_check', { method = ngx.HTTP_POST, body = os.time() })
  if not (res.status == ngx.HTTP_CREATED) then
    errors[#errors+1] = "memcache add: " .. res.status .. ": " .. res.body
  end

  res = ngx.location.capture('/session?id=health_check')
  if not (res.status == ngx.HTTP_OK) then
    errors[#errors+1] = "memcache get: " .. res.status .. ": " .. res.body
  end

  res = ngx.location.capture('/session?id=health_check', { method = ngx.HTTP_PUT, body = os.time() })
  if not (res.status == ngx.HTTP_CREATED) then
    errors[#errors+1] = "memcache set: " .. res.status .. ": " .. res.body
  end

  res = ngx.location.capture('/session?id=health_check', { method = ngx.HTTP_DELETE })
  if not (res.status == ngx.HTTP_OK) then
    errors[#errors+1] = "memcache delete: " .. res.status .. ": " .. res.body
  end

  return errors
end


local errors = get_errors()
local output = health_check.output(errors)

if (#errors > 0) then
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
else
  ngx.status = ngx.HTTP_OK
end

ngx.header.content_type = 'text/html'
ngx.print(output)
