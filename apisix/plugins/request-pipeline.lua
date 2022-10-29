--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local core = require("apisix.core")
local http = require("resty.http")
local tb_array_find = core.table.array_find


local return_status_schema = {
    type = "array",
    items = {
        type = "integer",
    },
}


local plugin_schema = {
    type = "object",
    properties = {
        timeout = {
            type = "integer",
            minimum = 1000,
            maximum = 60000,
            default = 3000,
            description = "timeout in milliseconds",
        },
        pipeline = {
            description = "request pipeline",
            type = "array",
            minItems = 1,
            items = {
                type = "object",
                properties = {
                    path = {
                        description = "path of the request",
                        type = "string",
                        minLength = 1
                    },
                    ssl_verify = {
                        type = "boolean",
                        default = true,
                    },
                    return_status = return_status_schema,
                },
                required = {"path"},
            },
        },
    },
    required = {"pipeline"},
}


local plugin_name = "request-pipeline"

local _M = {
    version = 0.1,
    priority = 12,
    name = plugin_name,
    schema = plugin_schema,
}


function _M.check_schema(conf)
    return core.schema.check(plugin_schema, conf)
end


function _M.access(conf, ctx)
    local resp, req_body, err, ok
    local pipeline = conf.pipeline
    local timeout = conf.timeout

    req_body, err = core.request.get_body()
    if err ~= nil then
        core.log.error("failed to get request body: ", err)
        return 503
    end

    local params = {
        method = ctx.var.request_method,
        headers = core.request.headers(ctx),
        query = core.request.get_uri_args(ctx),
        body = req_body,
    }

    local httpc = http.new()
    httpc:set_timeout(timeout)
    ok, err = httpc:connect("127.0.0.1", ngx.var.server_port)
    if not ok then
        return 500, {error_msg = "connect to apisix failed: " .. err}
    end

    for _, node in ipairs(pipeline) do
        params.path = node.path
        resp, err = httpc:request(params)
        if not resp then
            return 500, "request failed: " .. err
        end

        params.method = "POST"
        params.body = resp:read_body()

        if node.return_status then
            local i = tb_array_find(node.return_status, resp.status)

            if i then
                break
            end
        end
    end

    for key, value in pairs(resp.headers) do
        local lower_key = string.lower(key)
        if lower_key == "transfer-encoding"
            or lower_key == "connection" then
            goto continue
        end

        core.response.set_header(key, value)

        ::continue::
    end

    return resp.status, params.body
end


return _M
