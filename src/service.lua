local module = {}

-- checks if the string starts with the value
local function starts_with(str, starts)
  return string.sub(str, 1, string.len(starts)) == starts
end

-- find the longest subsequence
local function longest_subseq(tbl)
  local max = 0
  local max_i = 1
  for i,str in ipairs(tbl) do
    cur = string.len(str)
    if cur > max then
      max_i = i
      max = cur
    end
  end
  return tbl[max_i]
end

-- return the service mapping key with the longest subsequence match of the string
-- with host sub.subdomain.example.com
-- term is used to terminate the sequence, i.e. "." for subdomains, "/" for path
local function match_service(tbl, str, term)
  local subseqs = {}
  for cmpt,service in pairs(tbl) do
    if starts_with(str .. term, cmpt .. term) then
      table.insert(subseqs, cmpt)
    end
  end
  return tbl[longest_subseq(subseqs)]
end

-- Given a host of "sub.subdomain.example.org", and a subdomain_mapping table of {["sub.subdomain"]="name", ["sub"]="name2"}
-- return "name", since "sub.subdomain" is the longest matching subsequence
local function match_subdomain(host)
  local service = match_service(subdomain_mappings, host, ".")
  if not service then
    ngx.log(ngx.WARN, "==== no service found for host: " .. host)
  end
  return service
end

-- Given a path of "/api/service/collection/1/id", and a service_mapping table of {["/api/service"]="name", ["/api/service2"]="name2"}
-- return "name" since "/api/service" is the longest matching subsequence
-- matches the given url against the service_mappings, returns the service or nil
local function match_path(path)
  local service = match_service(service_mappings, path, "/")
  if not service then
    ngx.log(ngx.WARN, "==== no service found for path: " .. path)
  end
  return service
end

local function find_service(path, host)
  local service = match_path(path)
  if not service then
    service = match_subdomain(host)
  end
  return service
end

-- Get default url for given service. If none, return "/"
local function default_url_for_service(service)
  default_url = "/"
  for key,value in pairs(service_mappings) do
    if value == service then
      default_url = key
    end
  end
  return default_url
end

module.default_url_for_service = default_url_for_service
module.find_service = find_service
module.match_path = match_path
module.match_host = match_host

return module
