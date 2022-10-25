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
});

run_tests();

__DATA__

=== TEST 1: schema validation
--- config
    location /t {
        content_by_lua_block {
            local confs = {
                {pipeline = {}},
                {pipeline = {{uri = "/hello"}}},
                {pipeline = {{uri = ""}}},
                {
                    timeout = 3000,
                    pipeline = {{uri = "/hello"}},
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
property "pipeline" validation failed: failed to validate item 1: property "uri" validation failed: string too short, expected at least 1, got 0
ok


