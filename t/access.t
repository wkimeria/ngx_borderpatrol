use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

plan tests => $Test::Nginx::Socket::RepeatEach * 2 * blocks() + 1;

run_tests();

__DATA__

=== TEST 1: test w/ Auth-Token present in client request
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";

upstream b {
  server 127.0.0.1:$TEST_NGINX_SERVER_PORT; # self
}

--- config
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /auth {
    echo_status 200;
    echo_flush;
}
location /b/testpath {
    set $auth_token $http_auth_token;
    access_by_lua_file '../../build/usr/share/borderpatrol/access.lua';
    proxy_set_header Auth-Token $auth_token;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
Auth-Token: tokentokentokentoken
--- error_code: 200
--- response_body_like
Auth-Token: tokentokentoken.+everything is ok$

=== TEST 2: test w/o Auth-Token not present in client request but with valid session
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb",s="flexd"}
             account_resource = "/account"';
upstream b {
  server 127.0.0.1:$TEST_NGINX_SERVER_PORT; # self
}
--- config
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /auth {
    internal;
    echo_status 200;
    more_set_headers 'Auth-Token: tokentokentokentoken';
    echo_flush;
}
location /b/testpath {
    set $auth_token $http_auth_token;
    access_by_lua_file '../../build/usr/share/borderpatrol/access.lua';
    proxy_set_header Auth-Token $auth_token;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
Cookie: border_session=this-is-a-session-id # not checked here!
--- error_code: 200
--- response_body_like
Auth-Token: tokentokentoken.+everything is ok$

=== TEST 3: test w/ Expired Auth-Token present in client Ajax request
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";

upstream b {
  server 127.0.0.1:$TEST_NGINX_SERVER_PORT; # self
}
--- config
location /memc_setup {
    internal;
    set $memc_cmd $arg_cmd;
    set $memc_key $arg_key;

    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location = /session {
    internal;
    set $memc_key $arg_id;
    set $memc_value $arg_val;
    set $memc_exptime $arg_exptime;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /testpath {
    proxy_intercept_errors on;
    error_page 401  = @redirect;
    return 401;
}
location @redirect {
    # For Ajax requests, we want to return a 401 with a descriptive message
    if ($http_x_requested_with = "XMLHttpRequest") {
        more_set_headers 'Content-Type: application/json';
        return 401 '{"CODE": "SESSION_EXPIRED"}';
    }
    content_by_lua_file '../../build/usr/share/borderpatrol/redirect.lua';
}
location /auth {
    echo_status 200;
    echo_flush;
}
location /b/testpath {
    set $auth_token $http_auth_token;
    content_by_lua_file '../../build/usr/share/borderpatrol/access.lua';
    proxy_set_header Auth-Token $auth_token;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
Auth-Token: tokentokentokentoken
X-Requested-With: XMLHttpRequest
--- error_code: 401
--- response_headers
Content-Type: application/json
--- response_body
{"CODE": "SESSION_EXPIRED"}