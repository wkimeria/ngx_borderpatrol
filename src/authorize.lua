local json = require("json")
local sessionid = require("sessionid")

-------------------------------------------
--  Make the call to the Account Service
-------------------------------------------

local session_id = ngx.var.cookie_border_session

-- require session because the only valid scenario for arriving here is via redirect, which should have already set
-- session
if not session_id then
  ngx.log(ngx.INFO, "==== access denied: no session_id")
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end
ngx.log(ngx.DEBUG, "==== session_id: " .. session_id)

if not sessionid.is_valid(session_id) then
  ngx.log(ngx.INFO, "==== access denied: session id invalid " .. session_id)
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- Retrieve original target url and derive service
local res = ngx.location.capture('/session?id=BP_URL_SID_' .. session_id)

ngx.log(ngx.DEBUG, "==== GET /session?id=BP_URL_SID_" .. session_id .. " " .. res.status)

-- Get original downstream url they were going to before being redirected
original_url = res.body
original_host = ngx.req.get_headers()["Host"]

-- get service name from first part of original uri
local service_uri = string.match(original_url, "^/([^/]+)")
local service_host = string.match(original_host, "^([^.]+)")
local service = nil

-- catch calls to the account service resource from subdomain based routes
if service_uri and (("/" .. service_uri) == account_resource) then
  ngx.log(ngx.DEBUG, "==== trying to access account service")
  service = service_mappings[service_uri]
end

-- check for subdomain based routes first
if not service and service_host then
  ngx.log(ngx.DEBUG, "==== service host is: " .. service_host)
  service = subdomain_mappings[service_host]
else
  ngx.log(ngx.DEBUG, "==== no service host, trying service uri")
end

-- check for uri-resource based routes last
if not service and service_uri then
  service = service_mappings[service_uri]
  ngx.log(ngx.DEBUG, "==== service uri is: " .. service_uri)
else
  ngx.log(ngx.DEBUG, "==== no service uri")
  ngx.log(ngx.DEBUG, "==== original_url " .. original_url)
end

-- check service
if not service then
  if service_host then
    ngx.log(ngx.DEBUG, "==== no valid service for host provided: " .. service_host)
  end
  if service_uri then
    ngx.log(ngx.DEBUG, "==== no valid service for uri provided: " .. service_uri)
  end
  ngx.log(ngx.INFO, "==== no valid service found via uri or host")
  ngx.redirect(account_resource)
end

ngx.req.read_body()
local args = ngx.req.get_post_args()

-- the account service expects 'e=user@example.com&p=password&t=3&s=servicename'
ngx.log(ngx.DEBUG, "==== using service " .. service)
args['service'] = service
res = ngx.location.capture(account_resource, { method = ngx.HTTP_POST, body = ngx.encode_args(args) })

ngx.log(ngx.DEBUG, "==== POST " .. account_resource .. " " .. res.status .. " " .. res.body)

-- assume any 2xx is success
-- On failure, redirect to login

local statistics = require("statistics")

if res.status >= ngx.HTTP_SPECIAL_RESPONSE then
  statistics.log('login.failure')
  ngx.log(ngx.DEBUG, "==== Authorization against Account Service failed: " .. res.body)
  ngx.status = res.status
  -- pass through headers
  for k, v in pairs(res.header) do
    ngx.header[k] = v
  end
  ngx.print(res.body)
  return
end

-- parse the response body
local all_tokens_json = res.body
local all_tokens = json.decode(all_tokens_json)

-- looking for auth tokens
if not all_tokens then
  statistics.log('login.failure')
  ngx.log(ngx.DEBUG, "==== no tokens found, redirecting to " .. account_resource)
  ngx.redirect(account_resource)
end

-- looking for service token
if not all_tokens["service_tokens"][service] then
  statistics.log('login.failure')
  ngx.log(ngx.DEBUG, "==== parse failure, or service token not found, redirecting to " .. account_resource)
  ngx.redirect(account_resource)
end

statistics.log('login.success')

-- Extract token for specific service
local auth_token = all_tokens["service_tokens"][service]

-- store all tokens in memcache via internal subrequest
local res = ngx.location.capture('/session?id=BPSID_' .. session_id ..
  '&arg_exptime=' .. sessionid.EXPTIME, { body = all_tokens_json, method = ngx.HTTP_PUT })

ngx.log(ngx.DEBUG, "==== PUT /session?id=BPSID_" .. session_id  ..
  '&arg_exptime=' .. sessionid.EXPTIME .. " " .. res.status)

ngx.log(ngx.DEBUG, "==== redirecting to origin url " .. original_url)
ngx.redirect(original_url)
