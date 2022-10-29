use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();

add_block_preprocessor(sub {
    my ($block) = @_;

    # setup default conf.yaml
    my $extra_yaml_config = $block->extra_yaml_config // <<_EOC_;
plugins:
    - request-pipeline
    - serverless-pre-function
_EOC_

    $block->set_value("extra_yaml_config", $extra_yaml_config);

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if ((!defined $block->error_log) && (!defined $block->no_error_log)) {
        $block->set_value("no_error_log", "[error]");
    }

    my $main_config = $block->main_config // <<_EOC_;
env HOME;
_EOC_

    $block->set_value("main_config", $main_config);
});

run_tests();

__DATA__

=== TEST 1: schema validation
--- config
    location /t {
        content_by_lua_block {
            local confs = {
                {pipeline = {}},
                {pipeline = {{path = "/hello"}}},
                {pipeline = {{path = ""}}},
                {
                    timeout = 3000,
                    pipeline = {{path = "/hello"}},
                },
            }

            local plugin = require("apisix.plugins.request-pipeline")
            for _, conf in ipairs(confs) do
                local ok, err = plugin.check_schema(conf)
                if not ok then
                    ngx.say(err)
                else
                    ngx.say("ok")
                end
            end
        }
    }
--- response_body
property "pipeline" validation failed: expect array to have at least 1 items
ok
property "pipeline" validation failed: failed to validate item 1: property "path" validation failed: string too short, expected at least 1, got 0
ok



=== TEST 2: route config
--- config
    location /t {
        content_by_lua_block {
            local data = {
                {
                    uri = "/apisix/admin/routes/original",
                    data = [[{
                        "uri": "/original",
                        "plugins": {
                            "serverless-pre-function": {
                                "phase": "access",
                                "functions": [
                                    "return function(conf, ctx)
                                        local core = require('apisix.core')
                                        core.response.exit(200, 'original request')
                                    end"
                                ]
                            }
                        }
                    }]]
                },
                {
                    uri = "/apisix/admin/routes/trans1",
                    data = [[{
                        "uri": "/trans1",
                        "plugins": {
                            "serverless-pre-function": {
                                "phase": "access",
                                "functions": [
                                    "return function(conf, ctx)
                                        local core = require('apisix.core')

                                        local err = core.request.header(ctx, 'X-Trans1-ERROR')
                                        local status = err and 404 or 200

                                        local body = core.request.get_body()
                                        core.response.exit(status, body .. ' -> trans1')
                                    end"
                                ]
                            }
                        }
                    }]]
                },
                {
                    uri = "/apisix/admin/routes/trans2",
                    data = [[{
                        "uri": "/trans2",
                        "plugins": {
                            "serverless-pre-function": {
                                "phase": "access",
                                "functions": [
                                    "return function(conf, ctx)
                                        local core = require('apisix.core')
                                        local body = core.request.get_body()
                                        core.response.exit(200, body .. ' -> trans2')
                                    end"
                                ]
                            }
                        }
                    }]]
                }
            }

            local t = require("lib.test_admin").test

            for _, data in ipairs(data) do
                local code, body = t(data.uri, ngx.HTTP_PUT, data.data)
                ngx.say(code..body)
            end
        }
    }
--- response_body eval
"201passed\n" x 3



=== TEST 3: pipeline config
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/request-trans',
                ngx.HTTP_PUT,
                [[{
                    "uri": "/request-trans",
                    "plugins": {
                        "request-pipeline": {
                            "pipeline": [
                                {
                                    "path": "/original"
                                },
                                {
                                    "path": "/trans1",
                                    "return_status": [404]
                                },
                                {
                                    "path": "/trans2"
                                }
                            ]
                        }
                    }
                }]]
            )

            ngx.say(code..body)
        }
    }
--- response_body
201passed



=== TEST 4: original request
--- request
GET /original
--- response_body eval
"original request"



=== TEST 5: request pipeline
--- request
GET /request-trans
--- response_body eval
"original request -> trans1 -> trans2"



=== TEST 6: request pipeline with error
--- request
GET /request-trans
--- more_headers
X-Trans1-ERROR: 1
--- response_body eval
"original request -> trans1"
--- error_code: 404
