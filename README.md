# apisix-plugin-request-pipeline

[![Build Status][badge-action-img]][badge-action-url]

## Table of contents
- [Getting started](#getting-started)
- [Usage](#usage)
- [Useful links](#useful-links)

## Getting Started

This APISIX plugin helps pipelining requests and responses with Lua transformers.

[Back to TOC][TOC]

## Usage

Create request pipeline:

```shell
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/request-trans' \
-H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
-H 'Content-Type: application/json' \
-d '
{
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
}'
```

Create original request's route:

```shell
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/original' \
-H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
-H 'Content-Type: application/json' \
-d '
{
    "uri": "/original",
    "plugins": {
        "serverless-pre-function": {
            "phase": "access",
            "functions": [
                "return function(conf, ctx)
                    local core = require(\"apisix.core\")
                    core.response.exit(200, \"original request\")
                end"
            ]
        }
    }
}'
```

Use `serverless` plugin to create two corresponding trasformers:

```shell
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/trans1' \
-H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
-H 'Content-Type: application/json' \
-d '
{
    "uri": "/trans1",
    "plugins": {
        "serverless-pre-function": {
            "phase": "access",
            "functions": [
                "return function(conf, ctx)
                    local core = require(\"apisix.core\")

                    local err = core.request.header(ctx, \"X-Trans1-ERROR\")
                    local status = err and 404 or 200

                    local body = core.request.get_body()
                    core.response.exit(status, body .. \" -> trans1\")
                end"
            ]
        }
    }
}'
```

```shell
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/trans2' \
-H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
-H 'Content-Type: application/json' \
-d '
{
    "uri": "/trans2",
    "plugins": {
        "serverless-pre-function": {
            "phase": "access",
            "functions": [
                "return function(conf, ctx)
                    local core = require(\"apisix.core\")
                    local body = core.request.get_body()
                    core.response.exit(200, body .. \" -> trans2\")
                end"
            ]
        }
    }
}'
```

Test it!

```shell
curl -i -X GET "http://127.0.0.1:9080/request-trans"
```

Result:

```shell
original request -> trans1 -> trans2
```

[Back to TOC][TOC]

## Useful links
- [Getting started with GitHub Public Template][github-public-template]
- [What is APISIX Plugin][apisix-plugin]
- [APISIX Architecture Design][apisix-architecture-design]
- [APISIX Plugin Deveolpment][apisix-plugin-develop]
- [APISIX Code Style][apisix-code-style]
- [APISIX Debug Mode][apisix-debug-mode]
- [APISIX Testing Framework][apisix-testing-framework]
- [GitHub Actions][github-actions]

[Back to TOC][TOC]

[TOC]: #table-of-contents

[badge-action-url]: https://github.com/api7/apisix-plugin-template/actions
[badge-action-img]: https://github.com/api7/apisix-plugin-template/actions/workflows/ci.yml/badge.svg

[apisix]: https://github.com/apache/apisix
[apisix-architecture-design]: https://apisix.apache.org/docs/apisix/architecture-design/apisix
[apisix-code-style]: https://github.com/apache/apisix/blob/master/CODE_STYLE.md
[apisix-debug-mode]: https://apisix.apache.org/docs/apisix/architecture-design/debug-mode
[apisix-plugin]: https://apisix.apache.org/docs/apisix/architecture-design/plugin
[apisix-plugin-develop]: https://apisix.apache.org/docs/apisix/plugin-develop
[apisix-plugin-use-template]: https://github.com/api7/apisix-plugin-template/generate
[apisix-testing-framework]: https://apisix.apache.org/docs/apisix/internal/testing-framework

[continuous-integration]: https://en.wikipedia.org/wiki/Continuous_integration

[github-actions]: https://help.github.com/en/actions
[github-public-template]: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template
