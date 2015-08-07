local sessionid = require("sessionid")

local module = {}

local session_cookie_name = 'border_session'
local csrf_cookie_name = 'border_csrf'

--
-- Creates the cookie from the name and value parameters
--
local function make_cookie(name, value)
  return (name .. '=' .. value .. '; path=/; HttpOnly; Secure;')
end

--
-- Creates an empty value and sets the cookie as expired (now() - 1yr)
--
local function make_expired_cookie(name)
  return (make_cookie(name, '') .. 'expires=' .. ngx.cookie_time(ngx.time() - 3600 * 24 * 360))
end

--
-- Returns the cookie for sessions
-- session_id The id for the session cookie
--
local function gen_session(session_id)
  return make_cookie(session_cookie_name, session_id)
end

--
-- Creates the cookie for csrf protection, generating a unique id for it
--
local function gen_csrf()
  return make_cookie(csrf_cookie_name, sessionid.generate())
end

--
-- Mutates the Set-Cookie header with both the session and csrf cookies injected
-- session_id The id for the session cookie
--
local function set_cookie_header(session_id)
  ngx.header['Set-Cookie'] = {gen_session(session_id), gen_csrf()}
end

--
-- Mutates the Set-Cookie header with only the session cookie injected
-- session_id The id for the session cookie
--
local function set_session_cookie_header(session_id)
  ngx.header['Set-Cookie'] = gen_session(session_id)
end

--
-- Mutates the Set-Cookie header with expired cookies
--
local function expire_cookies()
  ngx.header['Set-Cookie'] = {make_expired_cookie(session_cookie_name),
                              make_expired_cookie(csrf_cookie_name)}
end

module.set_all = set_cookie_header
module.set_session = set_session_cookie_header
module.expire_all = expire_cookies

return module
