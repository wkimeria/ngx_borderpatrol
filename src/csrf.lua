local sessionid = require("sessionid")

local module = {}
local csrf_verified_hdr = 'X-Border-Csrf-Verified'
local csrf_incoming_hdr = 'X-Border-Csrf'

--
-- Boolean: token and header are present, also logs if false
-- token The cookie value
-- header The header value
--
local function csrf_present(token, header)
  if (token == nil) then
    ngx.log(ngx.DEBUG, "=== no csrf cookie")
  end

  if (header == nil) then
    ngx.log(ngx.DEBUG, "=== no csrf header")
  end

  return (not (not (token and header)))
end

--
-- Boolean: token and header are equivalent, also logs if false
-- token The cookie value
-- header The header value
--
local function csrf_equal(token, header)
  local equiv = token == header

  if (not equiv) then
    ngx.log(ngx.DEBUG, "=== cookie != header: " .. token .. " != " .. header)
  end

  return equiv
end

--
-- Boolean: cookie and header are valid, also logs if false
-- token The cookie value
-- header The header value
--
local function verify_csrf_tokens(token, header)
  local valid_cookie = sessionid.is_valid(token)
  local valid_header = sessionid.is_valid(header)

  if (not valid_cookie) then
    ngx.log(ngx.DEBUG, "=== invalid csrf cookie: " .. token)
  end

  if (not valid_header) then
    ngx.log(ngx.DEBUG, "=== invalid csrf header: " .. header)
  end

  return (valid_cookie and valid_header)
end

--
-- Boolean: the cookie and header tokens are present, valid, and equivalent
-- token The csrf cookie value
-- header The csrf header value
--
local function is_valid(token, header)
  return (csrf_present(token, header) and csrf_equal(token, header) and verify_csrf_tokens(token, header))
end

--
-- Sets the $csrf_verified nginx variable to 'true' or 'false'
--
local function set_csrf_verified()
  local csrf_tkn = ngx.var.cookie_border_csrf
  local csrf_hdr = ngx.req.get_headers()[csrf_incoming_hdr]

  if is_valid(csrf_tkn, csrf_hdr) then
    ngx.log(ngx.DEBUG, "csrf valid")
    ngx.var.csrf_verified = 'true'
  else
    ngx.var.csrf_verified = 'false'
  end

end

module.set_csrf_verified = set_csrf_verified

return module
