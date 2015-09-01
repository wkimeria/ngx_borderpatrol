use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

plan tests => $Test::Nginx::Socket::RepeatEach * 2 * blocks();

run_tests();

__DATA__

=== TEST 1: valid CSRF header and cookie
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
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /b/testpath {
    echo_location /setup;
    set $auth_token '';
    set $csrf_verified 'false';
    access_by_lua_file '../../build/usr/share/borderpatrol/border_vars.lua';
    proxy_set_header X-Border-Csrf-Verified $csrf_verified;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
X-Border-Csrf: MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
Cookie: border_csrf=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
--- error_code: 200
--- response_body_like
.+X-Border-Csrf-Verified: true.+everything is ok$

=== TEST 2: valid CSRF header and invalid cookie
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
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /b/testpath {
    echo_location /setup;
    set $csrf_verified 'false';
    access_by_lua_file '../../build/usr/share/borderpatrol/csrf.lua';
    proxy_set_header X-Border-Csrf-Verified $csrf_verified;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
X-Border-Csrf: MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
Cookie: border_csrf=invalidinvalidinvalid-**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
--- error_code: 200
--- response_body_like
.+X-Border-Csrf-Verified: false.+everything is ok$

=== TEST 3: valid CSRF cookie and invalid header
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
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /b/testpath {
    echo_location /setup;
    set $csrf_verified 'false';
    access_by_lua_file '../../build/usr/share/borderpatrol/csrf.lua';
    proxy_set_header X-Border-Csrf-Verified $csrf_verified;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
X-Border-Csrf: invalidinvalidinvalid-**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
Cookie: border_csrf=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
--- error_code: 200
--- response_body_like
.+X-Border-Csrf-Verified: false.+everything is ok$

=== TEST 4: valid CSRF cookie and missing header
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
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /b/testpath {
    echo_location /setup;
    set $csrf_verified 'false';
    access_by_lua_file '../../build/usr/share/borderpatrol/csrf.lua';
    proxy_set_header X-Border-Csrf-Verified $csrf_verified;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
Cookie: border_csrf=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
--- error_code: 200
--- response_body_like
.+X-Border-Csrf-Verified: false.+everything is ok$

=== TEST 5: valid CSRF header and missing cookie
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
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /b/testpath {
    echo_location /setup;
    set $csrf_verified 'false';
    access_by_lua_file '../../build/usr/share/borderpatrol/csrf.lua';
    proxy_set_header X-Border-Csrf-Verified $csrf_verified;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
X-Border-Csrf: MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
--- error_code: 200
--- response_body_like
.+X-Border-Csrf-Verified: false.+everything is ok$
