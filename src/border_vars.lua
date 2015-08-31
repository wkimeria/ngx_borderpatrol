local auth = require("access")
local csrf = require("csrf")

-- ensure we are setting these everytime
-- $auth_token
auth.set_auth_token()
-- $csrf_verified
csrf.set_csrf_verified()
