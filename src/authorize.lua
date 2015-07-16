local json = require("json")
local sessionid = require("sessionid")
local service_matcher = require("service")

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

-- get potential service names
local service = service_matcher.find_service(original_url, original_host)

-- if no service exists, then hit the account_resource
if not service then
  ngx.redirect(account_resource)
else
  ngx.log(ngx.DEBUG, "==== service found: " .. service)
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

-- Create a new session id after login to twart session fixation attacks
local new_session_id = sessionid.generate();

-- store all tokens in memcache via internal subrequest
local res = ngx.location.capture('/session?id=BPSID_' .. new_session_id ..
  '&arg_exptime=' .. sessionid.EXPTIME, { body = all_tokens_json, method = ngx.HTTP_PUT })

ngx.log(ngx.DEBUG, "==== PUT /session?id=BPSID_" .. new_session_id  ..
  '&arg_exptime=' .. sessionid.EXPTIME .. " " .. res.status)

-- Ensure we set a new cookie with the new session id
ngx.log(ngx.DEBUG, "==== setting new cookie session_id " .. new_session_id)
ngx.header['Set-Cookie'] = 'border_session=' .. new_session_id .. '; path=/; HttpOnly; Secure;'

-- If no original url use default url for service
if not original_url or original_url == "" then
  original_url = service_matcher.default_url_for_service(service)
  ngx.log(ngx.DEBUG, "==== blank original url, setting to default of " .. original_url)
end

ngx.log(ngx.DEBUG, "==== redirecting to origin url " .. original_url)
ngx.redirect(original_url)
